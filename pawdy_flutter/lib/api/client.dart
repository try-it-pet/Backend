import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/tryon.dart';

/// Pawdy 백엔드(FastAPI) 클라이언트.
/// 운영 = Railway. 빌드 시 --dart-define=API_BASE=... 로 재정의 가능.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://pawdy-api-production.up.railway.app',
);

class Api {
  static String? _token;
  static bool get isLoggedIn => _token != null;

  static Map<String, String> _authHeaders() =>
      _token != null ? {'Authorization': 'Bearer $_token'} : {};

  /// 둘러보기(dev-login) — 키 없이 토큰 발급. quota·tryon 이 인증을 요구하므로 사용.
  static Future<void> devLogin({String nickname = '초코집사'}) async {
    final r = await http.post(
      Uri.parse('$apiBase/auth/dev-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nickname': nickname}),
    );
    if (r.statusCode != 200) throw Exception('dev-login ${r.statusCode}');
    _token = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['token'] as String;
  }

  /// 상품 카탈로그.
  static Future<List<Product>> fetchProducts() async {
    final r = await http.get(Uri.parse('$apiBase/products'));
    if (r.statusCode != 200) throw Exception('products ${r.statusCode}');
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 상품 카드 이미지 절대 URL (image 우선, 없으면 ref_image). 상대경로는 apiBase 결합.
  static String? imageUrl(Product p) => _abs(p.image ?? p.refImage);

  /// 결과 이미지 절대 URL.
  static String resultImageUrl(String url) => _abs(url) ?? url;

  static String? _abs(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$apiBase$path';
  }

  /// AI 피팅 잡 생성(멀티파트). petImageBytes 없으면 mock 프로바이더에서만 동작.
  static Future<TryOnJob> createTryOn({
    required int productId,
    required String size,
    String provider = 'mock',
    int? petId,
    String? style,
    String? composition,
    String? background,
    Uint8List? petImageBytes,
    String petImageName = 'pet.jpg',
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/tryon'))
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
          filename: petImageName));
    }
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode != 200) {
      throw _apiError(r, 'tryon 생성 실패');
    }
    return TryOnJob.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  static Future<TryOnJob> getTryOn(String jobId) async {
    final r = await http.get(Uri.parse('$apiBase/tryon/$jobId'));
    if (r.statusCode != 200) throw Exception('tryon get ${r.statusCode}');
    return TryOnJob.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// 잡 생성 후 done/failed 까지 폴링(2초 간격, 최대 ~360초 — LoRA 콜드스타트 대응).
  static Future<TryOnJob> runTryOn({
    required int productId,
    required String size,
    String provider = 'mock',
    int? petId,
    String? style,
    String? composition,
    String? background,
    Uint8List? petImageBytes,
  }) async {
    var job = await createTryOn(
      productId: productId,
      size: size,
      provider: provider,
      petId: petId,
      style: style,
      composition: composition,
      background: background,
      petImageBytes: petImageBytes,
    );
    for (var i = 0; i < 180; i++) {
      if (job.isFinished) return job;
      await Future.delayed(const Duration(seconds: 2));
      job = await getTryOn(job.id);
    }
    return job;
  }

  /// 서버 detail 메시지 + status 를 담은 예외(횟수제한 402/401 표시용).
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
