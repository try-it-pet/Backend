/// AI 피팅 생성 이력 항목 (라이브러리).
class Fitting {
  final int id;
  final int productId;
  final String imageUrl;
  final String kind; // tryon | fourcut
  final String? style;
  final String createdAt;

  const Fitting({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.kind,
    this.style,
    required this.createdAt,
  });

  bool get isFourcut => kind == 'fourcut';
  bool get isSvg => imageUrl.endsWith('.svg'); // mock 프리뷰(이미지 아님)

  factory Fitting.fromJson(Map<String, dynamic> j) => Fitting(
        id: j['id'] as int,
        productId: (j['product_id'] as num).toInt(),
        imageUrl: j['image_url'] as String? ?? '',
        kind: j['kind'] as String? ?? 'tryon',
        style: j['style'] as String?,
        createdAt: j['created_at'] as String? ?? '',
      );
}
