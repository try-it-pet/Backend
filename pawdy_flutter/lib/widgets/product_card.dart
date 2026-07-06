import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../theme/tokens.dart';

/// 홈·카테고리·찜에서 쓰는 상품 카드. 1:1 이미지 + AI추천 배지 + 찜 하트 + 브랜드/이름/가격.
class ProductCard extends StatelessWidget {
  final Product product;
  final bool liked;
  final bool showBadge;
  final VoidCallback? onTap;
  final VoidCallback? onLike;

  const ProductCard({
    super.key,
    required this.product,
    this.liked = false,
    this.showBadge = true,
    this.onTap,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final img = Api.imageUrl(product);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: T.soft,
                      child: img == null
                          ? const _ImgLabel()
                          : Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _ImgLabel(),
                            ),
                    ),
                  ),
                ),
                if (showBadge && product.aiPick)
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('AI 추천',
                          style: TextStyle(
                              color: T.accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2)),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onLike,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: liked ? T.accent : T.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(product.brand,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: T.muted2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2)),
          const SizedBox(height: 3),
          Text(product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  color: T.ink,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: won(product.price),
                style: const TextStyle(
                    fontSize: 15,
                    color: T.ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4)),
            const TextSpan(
                text: '원',
                style: TextStyle(
                    fontSize: 12, color: T.muted, fontWeight: FontWeight.w600)),
          ])),
        ],
      ),
    );
  }
}

class _ImgLabel extends StatelessWidget {
  const _ImgLabel();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('상품 사진',
            style: TextStyle(
                fontSize: 10.5, color: T.muted2, fontWeight: FontWeight.w600)),
      );
}
