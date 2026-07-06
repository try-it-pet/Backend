import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

/// Pawdy 백엔드(FastAPI) 클라이언트.
/// 운영 = Railway. 빌드 시 --dart-define=API_BASE=... 로 재정의 가능.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://pawdy-api-production.up.railway.app',
);

class Api {
  /// 상품 카탈로그. 이미지 경로가 상대경로면 apiBase 를 붙여 절대 URL 로 만든다.
  static Future<List<Product>> fetchProducts() async {
    final r = await http.get(Uri.parse('$apiBase/products'));
    if (r.statusCode != 200) {
      throw Exception('products ${r.statusCode}');
    }
    final data = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 상품 카드 이미지 절대 URL (image 우선, 없으면 ref_image). 상대경로는 apiBase 결합.
  static String? imageUrl(Product p) {
    final path = p.image ?? p.refImage;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$apiBase$path';
  }
}
