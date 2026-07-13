import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/tryon.dart';
import '../models/user.dart';
import '../models/commerce.dart';
import '../models/review.dart';
import '../models/fitting.dart';
import '../models/shop.dart';


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
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static bool get isLoggedIn => _token != null;

  /// 토큰 설정 + 기기 보안 저장소에 영속화(앱 재시작 시 로그인 유지). null 이면 삭제(로그아웃).
  static void setToken(String? t) {
    _token = t;
    if (t == null) {
      _storage.delete(key: _tokenKey).catchError((_) {});
    } else {
      _storage.write(key: _tokenKey, value: t).catchError((_) {});
    }
  }

  /// 앱 부팅 시 저장된 토큰 복원. (만료/무효 토큰은 이후 fetchMe 가 걸러낸다)
  static Future<void> restoreToken() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
  }

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
    setToken(j['token'] as String);
    return User.fromJson(j['user'] as Map<String, dynamic>);
  }

  static Future<User?> fetchMe() async {
    if (_token == null) return null;
    final r = await http.get(Uri.parse('$apiBase/auth/me'), headers: _authHeaders());
    if (r.statusCode != 200) return null;
    return User.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  // ── 상품 ──
  static Future<List<Product>> fetchProducts({String? q}) async {
    final uri = Uri.parse('$apiBase/products').replace(
      queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
    );
    final r = await http.get(uri);
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

  /// 임시 결제대기 주문 생성
  static Future<Order> createPendingOrder() async {
    final r = await http.post(Uri.parse('$apiBase/me/orders/pending'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '결제 준비 실패');
    return Order.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// 토스 페이먼츠 결제 승인 요청
  static Future<Order> confirmPayment({
    required String paymentKey,
    required int orderId,
    required int amount,
  }) async {
    final body = jsonEncode({
      'paymentKey': paymentKey,
      'orderId': orderId,
      'amount': amount,
    });
    final headers = _authHeaders()..addAll({'Content-Type': 'application/json'});
    final r = await http.post(
      Uri.parse('$apiBase/me/payments/confirm'),
      headers: headers,
      body: body,
    );
    if (r.statusCode != 200) throw _apiError(r, '결제 최종 승인 실패');
    return Order.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// 구매 확정 요청
  static Future<Order> confirmOrder(int orderId) async {
    final r = await http.post(
      Uri.parse('$apiBase/me/orders/$orderId/confirm'),
      headers: _authHeaders(),
    );
    if (r.statusCode != 200) throw _apiError(r, '구매확정 실패');
    return Order.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// 이메일 회원가입
  static Future<User> registerEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
      'nickname': nickname,
    });
    final r = await http.post(
      Uri.parse('$apiBase/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (r.statusCode != 200) throw _apiError(r, '회원가입 실패');
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    setToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// 이메일 로그인
  static Future<User> loginEmail({
    required String email,
    required String password,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
    });
    final r = await http.post(
      Uri.parse('$apiBase/auth/login/email'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (r.statusCode != 200) throw _apiError(r, '로그인 실패');
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    setToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// 구글 로그인
  static Future<User> loginGoogle({
    required String idToken,
    String? nickname,
  }) async {
    final body = jsonEncode({
      'idToken': idToken,
      'nickname': nickname,
    });
    final r = await http.post(
      Uri.parse('$apiBase/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (r.statusCode != 200) throw _apiError(r, '구글 로그인 실패');
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    setToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// 구글 클라이언트 ID 환경변수 조회
  static Future<String> fetchGoogleClientId() async {
    final r = await http.get(Uri.parse('$apiBase/auth/config'));
    if (r.statusCode != 200) return '';
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return data['google_client_id'] as String? ?? '';
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

  static Future<Pet?> createPet({
    required String name,
    required String species,
    double? weightKg,
    double? chestCm,
    double? neckCm,
    double? backCm,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (_token == null) return null;
    final uri = Uri.parse('$apiBase/me/pets');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_authHeaders());

    req.fields['name'] = name;
    req.fields['species'] = species;
    if (weightKg != null) req.fields['weight_kg'] = weightKg.toString();
    if (chestCm != null) req.fields['chest_cm'] = chestCm.toString();
    if (neckCm != null) req.fields['neck_cm'] = neckCm.toString();
    if (backCm != null) req.fields['back_cm'] = backCm.toString();

    if (imageBytes != null && imageName != null) {
      final multipartFile = http.MultipartFile.fromBytes(
        'image_file',
        imageBytes,
        filename: imageName,
      );
      req.files.add(multipartFile);
    }

    final streamRes = await req.send();
    final r = await http.Response.fromStream(streamRes);

    if (r.statusCode != 200 && r.statusCode != 201) throw _apiError(r, '펫 등록 실패');
    return Pet.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<void> deletePet(int petId) async {
    final r = await http.delete(
      Uri.parse('$apiBase/me/pets/$petId'),
      headers: _authHeaders(),
    );
    if (r.statusCode != 200) throw _apiError(r, '펫 삭제 실패');
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

  static Future<Review> createReview({
    required int productId,
    required int rating,
    required String text,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/me/reviews'))
      ..headers.addAll(_authHeaders())
      ..fields['product_id'] = '$productId'
      ..fields['rating'] = '$rating'
      ..fields['text'] = text;

    if (imageBytes != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'image_file',
        imageBytes,
        filename: imageFilename ?? 'review_photo.jpg',
      ));
    }

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) throw _apiError(res, '리뷰 작성 실패');
    return Review.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
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

  // ── 알림 센터 ──
  static Future<List<NotificationItem>> fetchNotifications() async {
    if (_token == null) return [];
    final r = await http.get(Uri.parse('$apiBase/me/notifications'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '알림 조회 실패');
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return data.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> markNotificationRead(int notifId) async {
    final r = await http.post(Uri.parse('$apiBase/me/notifications/$notifId/read'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '알림 읽음 처리 실패');
  }

  static Future<void> markAllNotificationsRead() async {
    final r = await http.post(Uri.parse('$apiBase/me/notifications/read-all'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '전체 알림 읽음 처리 실패');
  }

  static Future<void> deleteNotification(int notifId) async {
    final r = await http.delete(Uri.parse('$apiBase/me/notifications/$notifId'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '알림 삭제 실패');
  }

  static Future<void> deleteAllNotifications() async {
    final r = await http.delete(Uri.parse('$apiBase/me/notifications'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '전체 알림 삭제 실패');
  }


  // ── 상점 & 상품 등록 ──
  static Future<Shop?> fetchMyShop() async {
    if (_token == null) return null;
    final r = await http.get(Uri.parse('$apiBase/products/shops/me'), headers: _authHeaders());
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body == null) return null;
    return Shop.fromJson(body as Map<String, dynamic>);
  }

  static Future<Shop> createShop(String name, String? description) async {
    final r = await http.post(
      Uri.parse('$apiBase/products/shops'),
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'description': description}),
    );
    if (r.statusCode != 200 && r.statusCode != 201) throw _apiError(r, '상점 등록 실패');
    return Shop.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<Product> createProduct({
    required String brand,
    required String name,
    required int price,
    required String category,
    required String species,
    required bool fittable,
    String? url,
    List<String>? sizes,
    int stock = 99,
    required Uint8List imageBytes,
    required String imageFilename,
    Uint8List? refImageBytes,
    String? refImageFilename,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/products'))
      ..headers.addAll(_authHeaders())
      ..fields['brand'] = brand
      ..fields['name'] = name
      ..fields['price'] = '$price'
      ..fields['category'] = category
      ..fields['species'] = species
      ..fields['fittable'] = fittable.toString()
      ..fields['url'] = url ?? ''
      ..fields['stock'] = '$stock';

    if (sizes != null && sizes.isNotEmpty) {
      req.fields['sizes'] = jsonEncode(sizes);
    }
    req.files.add(http.MultipartFile.fromBytes(
      'image_file',
      imageBytes,
      filename: imageFilename,
    ));
    if (fittable && refImageBytes != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'ref_image_file',
        refImageBytes,
        filename: refImageFilename ?? 'ref_image.jpg',
      ));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) throw _apiError(res, '상품 등록 실패');
    return Product.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<List<Product>> fetchSellerProducts() async {
    final r = await http.get(Uri.parse('$apiBase/products/seller/my-products'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '등록 상품 조회 실패');
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Product> updateProduct(int id, Map<String, dynamic> body) async {
    final r = await http.put(
      Uri.parse('$apiBase/products/seller/products/$id'),
      headers: {..._authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw _apiError(r, '상품 수정 실패');
    return Product.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<void> deleteProduct(int id) async {
    final r = await http.delete(Uri.parse('$apiBase/products/seller/products/$id'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '상품 삭제 실패');
  }

  static Future<List<Order>> fetchSellerOrders() async {
    final r = await http.get(Uri.parse('$apiBase/products/seller/my-orders'), headers: _authHeaders());
    if (r.statusCode != 200) throw _apiError(r, '들어온 주문 조회 실패');
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Order> updateOrderStatus(int orderId, String status, {String? carrier, String? trackingNo}) async {
    final r = await http.patch(
      Uri.parse('$apiBase/products/seller/orders/$orderId/status'),
      headers: _authHeaders(),
      body: {
        'status': status,
        if (carrier != null) 'carrier': carrier,
        if (trackingNo != null) 'tracking_no': trackingNo,
      },
    );
    if (r.statusCode != 200) throw _apiError(r, '배송 상태 수정 실패');
    return Order.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
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
    List<Uint8List>? petImagesBytes,
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
    if (petImagesBytes != null) {
      for (var i = 0; i < petImagesBytes.length; i++) {
        req.files.add(http.MultipartFile.fromBytes('pet_images', petImagesBytes[i],
            filename: 'pet$i.jpg'));
      }
    }
    final r = await http.Response.fromStream(await req.send());
    // 생성 잡 접수는 202 Accepted (비동기) — 200/202 둘 다 정상
    if (r.statusCode != 200 && r.statusCode != 202) throw _apiError(r, '생성 실패');
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
    List<Uint8List>? petImagesBytes,
  }) =>
      _createJob('/tryon/fourcut',
              productId: productId,
              size: size,
              provider: provider,
              petId: petId,
              style: style,
              petImageBytes: petImageBytes,
              petImagesBytes: petImagesBytes)
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
