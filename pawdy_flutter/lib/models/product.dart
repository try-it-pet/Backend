/// 백엔드 GET /products 응답 항목. models.py Product 스키마와 일치.
class Product {
  final int id;
  final int? shopId;
  final String brand;
  final String name;
  final int price;
  final int fit; // AI 핏 점수(%) — fit>=93 이면 'AI 추천' 라벨
  final String category; // care|fashion|active|wellness|home
  final String species; // dog|cat|all
  final bool fittable;
  final String? image; // 상품 카드 이미지 경로(백엔드 정적) 또는 URL
  final String? refImage; // 옷 레퍼런스(AI 피팅용)
  final String? url; // 원 판매처 링크
  final List<String>? sizes; // 없으면 Free(단일)
  final int? stock; // 재고량

  const Product({
    required this.id,
    this.shopId,
    required this.brand,
    required this.name,
    required this.price,
    required this.fit,
    required this.category,
    required this.species,
    required this.fittable,
    this.image,
    this.refImage,
    this.url,
    this.sizes,
    this.stock,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        shopId: j['shop_id'] as int?,
        brand: j['brand'] as String? ?? '',
        name: j['name'] as String? ?? '',
        price: (j['price'] as num?)?.toInt() ?? 0,
        fit: (j['fit'] as num?)?.toInt() ?? 0,
        category: j['category'] as String? ?? 'fashion',
        species: j['species'] as String? ?? 'dog',
        fittable: j['fittable'] as bool? ?? false,
        image: j['image'] as String?,
        refImage: j['ref_image'] as String?,
        url: j['url'] as String?,
        sizes: (j['sizes'] as List?)?.map((e) => e.toString()).toList(),
        stock: (j['stock'] as num?)?.toInt(),
      );

  bool get aiPick => fit >= 93;
  bool get isOutOfStock => (stock ?? 0) <= 0;
}

