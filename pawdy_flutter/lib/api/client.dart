import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/tryon.dart';
import '../models/user.dart';
import '../models/commerce.dart';
import '../models/review.dart';
import '../models/fitting.dart';

/// Pawdy 백엔드(FastAPI) 클라이언트.
/// 운영 = Railway. 빌드 시 --dart-define=API_BASE=... 로 재정의 가능.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://pawdy-api-production.up.railway.app',
);

/// 네이티브 카카오 로그인 후 앱으로 복귀할 딥링크(백엔드 허용목록에 등록됨).
const String appRedirect = 'pawdy://login';

class Api {
  static String? _token;
  static bool get isLoggedIn => _token != null;
  static void setToken(String? t) => _token = t;

  static Map<String, String> _authHeaders() =>
      _token != null ? {'Authorization': 'Bearer $_token'} : {};

  // ── 인증 ──
  static String kakaoLoginUrl() =>
      '$apiBase/auth/kakao/login?next=${Uri.encodeComponent(appRedirect)}';

  static Future<User> devLogin({String nickname = '초코집사'}) async {
    final r = await http.post(
      Uri.parse('$apiBase/auth/dev-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nickname': nickname}),
    );
    if (r.statusCode != 200) throw _apiError(r, 'dev-login 실패');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    _token = j['token'] as String;
    return User.fromJson(j['user'] as Map<String, dynamic>);
  }

  static Future<User?> fetchMe() async {
    if (_token == null) return null;
    final r = await http.get(Uri.parse('$apiBase/auth/me'), headers: _authHeaders());
    if (r.statusCode != 200) return null;
    return User.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── 상품 ──
  static Future<List<Product>> fetchProducts() async {
    final r = await http.get(Uri.parse('$apiBase/products'));
    if (r.statusCode != 200) throw Exception('products ${r.statusCode}');
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String? imageUrl(Product p) => _abs(p.image ?? p.refImage);
  static String resultImageUrl(String url) => _abs(url) ?? url;
  static String? _abs(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$apiBase$path';
  }

  // ── 찜(좋아요) ──
  static Future<List<int>> fetchLikes() async {
    final r = await http.get(Uri.parse('$apiBase/me/likes'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, 'likes 실패');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => (e as num).toInt())
        .toList();
  }

  /// 토글 후 서버의 최신 찜 목록(likedIds) 반환.
  static Future<List<int>> toggleLike(int productId) async {
    final r = await http.post(Uri.parse('$apiBase/me/likes/$productId'),
        headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, 'like 실패');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (j['likedIds'] as List).map((e) => (e as num).toInt()).toList();
  }

  // ── 장바구니 / 주문 ──
  static List<CartItem> _cartFrom(http.Response r) =>
      (jsonDecode(utf8.decode(r.bodyBytes)) as List)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();

  static Future<List<CartItem>> addToCart(int productId, String size,
      {int qty = 1}) async {
    final r = await http.post(
      Uri.parse('$apiBase/me/cart'),
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({'product_id': productId, 'size': size, 'qty': qty}),
    );
    if (r.statusCode != 200) throw _apiError(r, '담기 실패');
    return _cartFrom(r);
  }

  static Future<List<CartItem>> fetchCart() async {
    final r = await http.get(Uri.parse('$apiBase/me/cart'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '장바구니 실패');
    return _cartFrom(r);
  }

  static Future<List<CartItem>> removeCartItem(int itemId) async {
    final r = await http.delete(Uri.parse('$apiBase/me/cart/$itemId'),
        headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '삭제 실패');
    return _cartFrom(r);
  }

  /// 체크아웃(장바구니 → 주문 생성). 구매 시 AI 생성 횟수도 충전됨.
  static Future<Order> checkout() async {
    final r = await http.post(Uri.parse('$apiBase/me/orders'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '결제 실패');
    return Order.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── 통계 ──
  static Future<Stats> fetchStats() async {
    final r = await http.get(Uri.parse('$apiBase/me/stats'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, 'stats 실패');
    return Stats.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── 펫 ──
  static Future<List<Pet>> fetchPets() async {
    if (_token == null) return [];
    final r = await http.get(Uri.parse('$apiBase/me/pets'), headers: _authHeaders());
    if (r.statusCode != 200) return [];
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Pet?> createPet(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$apiBase/me/pets'),
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw _apiError(r, '펫 등록 실패');
    return Pet.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── 주문 / AI 생성 잔여 횟수 ──
  static Future<List<Order>> fetchOrders() async {
    final r = await http.get(Uri.parse('$apiBase/me/orders'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, 'orders 실패');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 리뷰 ──
  static Future<ProductReviews> fetchProductReviews(int productId) async {
    final r = await http.get(Uri.parse('$apiBase/products/$productId/reviews'));
    if (r.statusCode != 200) throw _apiError(r, 'reviews 실패');
    return ProductReviews.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<List<Review>> fetchMyReviews() async {
    final r = await http.get(Uri.parse('$apiBase/me/reviews'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '내 리뷰 실패');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Review> createReview(int productId, int rating, String text) async {
    final r = await http.post(
      Uri.parse('$apiBase/me/reviews'),
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({'product_id': productId, 'rating': rating, 'text': text}),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw _apiError(r, '리뷰 작성 실패');
    return Review.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── AI 피팅 이력 ──
  static Future<List<Fitting>> fetchFittings() async {
    final r = await http.get(Uri.parse('$apiBase/me/fittings'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '피팅 기록 실패');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => Fitting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Generations?> fetchGenerations() async {
    if (_token == null) return null;
    final r = await http.get(Uri.parse('$apiBase/me/generations'), headers: _authHeaders());
    if (r.statusCode != 200) return null;
    return Generations.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── AI 피팅 / 인생네컷 ──
  static Future<TryOnJob> _createJob(
    String path, {
    required int productId,
    required String size,
    required String provider,
    int? petId,
    String? style,
    String? composition,
    String? background,
    Uint8List? petImageBytes,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase$path'))
      ..headers.addAll(_authHeaders())
      ..fields['product_id'] = '$productId'
      ..fields['size'] = size
      ..fields['provider'] = provider;
    if (petId != null) req.fields['pet_id'] = '$petId';
    if (style != null) req.fields['style'] = style;
    if (composition != null) req.fields['composition'] = composition;
    if (background != null) req.fields['background'] = background;
    if (petImageBytes != null) {
      req.files.add(http.MultipartFile.fromBytes('pet_image', petImageBytes,
          filename: 'pet.jpg'));
    }
    final r = await http.Response.fromStream(await req.send());
    if (r.statusCode != 200) throw _apiError(r, '생성 실패');
    return TryOnJob.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<TryOnJob> getTryOn(String jobId) async {
    final r = await http.get(Uri.parse('$apiBase/tryon/$jobId'));
    if (r.statusCode != 200) throw Exception('tryon get ${r.statusCode}');
    return TryOnJob.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<TryOnJob> _poll(TryOnJob job) async {
    for (var i = 0; i < 180; i++) {
      if (job.isFinished) return job;
      await Future.delayed(const Duration(seconds: 2));
      job = await getTryOn(job.id);
    }
    return job;
  }

  static Future<TryOnJob> runTryOn({
    required int productId,
    required String size,
    String provider = 'mock',
    int? petId,
    String? style,
    String? composition,
    String? background,
    Uint8List? petImageBytes,
  }) =>
      _createJob('/tryon',
              productId: productId,
              size: size,
              provider: provider,
              petId: petId,
              style: style,
              composition: composition,
              background: background,
              petImageBytes: petImageBytes)
          .then(_poll);

  static Future<TryOnJob> runFourcut({
    required int productId,
    required String size,
    String provider = 'mock',
    int? petId,
    String? style,
    Uint8List? petImageBytes,
  }) =>
      _createJob('/tryon/fourcut',
              productId: productId,
              size: size,
              provider: provider,
              petId: petId,
              style: style,
              petImageBytes: petImageBytes)
          .then(_poll);

  static ApiException _apiError(http.Response r, String fallback) {
    String detail = fallback;
    try {
      detail = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['detail']
              ?.toString() ??
          fallback;
    } catch (_) {}
    return ApiException(detail, r.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}
