class Review {
  final int id;
  final int productId;
  final String nickname;
  final int rating;
  final String text;
  final String createdAt;

  const Review({
    required this.id,
    required this.productId,
    required this.nickname,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as int,
        productId: (j['product_id'] as num).toInt(),
        nickname: j['nickname'] as String? ?? '익명',
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        text: j['text'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

class ProductReviews {
  final int count;
  final double average;
  final List<Review> items;
  const ProductReviews(
      {this.count = 0, this.average = 0, this.items = const []});

  factory ProductReviews.fromJson(Map<String, dynamic> j) => ProductReviews(
        count: (j['count'] as num?)?.toInt() ?? 0,
        average: (j['average'] as num?)?.toDouble() ?? 0,
        items: ((j['items'] as List?) ?? [])
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
