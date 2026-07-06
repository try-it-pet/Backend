import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/review.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;
import 'detail_screen.dart' show Stars;

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late Future<List<Review>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchMyReviews();
  }

  String _productName(int id) {
    for (final p in appState.products) {
      if (p.id == id) return '${p.brand} ${p.name}';
    }
    return '상품 #$id';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            const PawdyBar(title: '리뷰 관리'),
            Expanded(
              child: FutureBuilder<List<Review>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: T.accent, strokeWidth: 3));
                  }
                  final reviews = snap.data ?? [];
                  if (snap.hasError || reviews.isEmpty) {
                    return _empty();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(reviews[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Review r) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_productName(r.productId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: T.ink)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stars(r.rating.toDouble(), size: 14),
                Text(r.createdAt.split('T').first,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: T.muted2,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            if (r.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.text,
                  style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: T.sub,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      );

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: T.soft, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.rate_review_outlined,
                  color: Color(0xFFC4BDB3), size: 28),
            ),
            const SizedBox(height: 18),
            const Text('아직 작성한 리뷰가 없어요',
                style: TextStyle(
                    fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('상품 상세에서 첫 리뷰를 남겨보세요',
                style: TextStyle(
                    fontSize: 12.5, color: T.muted2, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
