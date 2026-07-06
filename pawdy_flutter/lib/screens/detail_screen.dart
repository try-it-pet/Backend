import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

/// 카테고리별 상품 정보 문구.
const _detailCopy = {
  'fashion': [
    '부드러운 안감으로 착용감이 뛰어난 데일리 아이템. 목과 가슴 둘레를 넉넉하게 디자인해 편안하게 착용할 수 있어요.',
    '소재',
    '극세사 / 폴리'
  ],
  'care': ['해외 원 판매처에서 직배송되는 정품으로, 현지 보호자 리뷰로 검증된 베스트셀러입니다.', '배송', '해외직구 정품'],
  'active': ['견고한 마감과 실사용 중심 설계로 현지에서 오래 사랑받아온 아웃도어 아이템입니다.', '배송', '해외직구 정품'],
  'wellness': ['우리 아이의 건강을 위한 웰니스 아이템. 급여량·주의사항은 원 판매처 가이드를 확인해 주세요.', '배송', '해외직구 정품'],
  'home': ['우리 집 공간에 자연스럽게 어우러지는 홈 아이템. 조립·관리가 쉬워 처음 들이는 집사에게도 부담 없어요.', '배송', '해외직구 정품'],
};

class DetailScreen extends StatelessWidget {
  final Product product;
  const DetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final img = Api.imageUrl(product);
    final copy = _detailCopy[product.category] ?? _detailCopy['fashion']!;
    final sizes = product.sizes;
    final sizeText = sizes != null && sizes.isNotEmpty ? sizes.join(' · ') : 'Free (단일 사이즈)';
    return Scaffold(
      backgroundColor: T.paper,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        color: T.soft,
                        child: img == null
                            ? const Center(
                                child: Text('상품 사진',
                                    style: TextStyle(color: T.muted2)))
                            : Image.network(img, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 14,
                      child: _circleBtn(Icons.arrow_back_ios_new,
                          () => Navigator.of(context).pop()),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.brand,
                          style: const TextStyle(
                              fontSize: 13,
                              color: T.muted2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(product.name,
                          style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: T.ink)),
                      const SizedBox(height: 11),
                      Text.rich(TextSpan(children: [
                        const TextSpan(
                            text: '23%  ',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: T.accent)),
                        TextSpan(
                            text: won(product.price),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: T.ink)),
                        const TextSpan(
                            text: '원',
                            style: TextStyle(fontSize: 15, color: T.ink)),
                      ])),
                      const SizedBox(height: 24),
                      const Text('상품 정보',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: T.ink)),
                      const SizedBox(height: 12),
                      Text(copy[0] as String,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.7,
                              color: T.sub,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _spec(copy[1] as String, copy[2] as String)),
                        const SizedBox(width: 10),
                        Expanded(child: _spec('사이즈 범위', sizeText)),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(context),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: T.ink),
        ),
      );

  Widget _spec(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: T.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: T.ink)),
          ],
        ),
      );

  Widget _bottomBar(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
            color: T.paper, border: Border(top: BorderSide(color: T.line))),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: appState,
              builder: (_, __) {
                final on = appState.isLiked(product.id);
                return GestureDetector(
                  onTap: () => appState.toggleLike(product.id),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: T.line),
                    ),
                    child: Icon(on ? Icons.favorite : Icons.favorite_border,
                        color: on ? T.accent : T.ink, size: 23),
                  ),
                );
              },
            ),
            const SizedBox(width: 11),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('장바구니에 담았어요'),
                        duration: Duration(milliseconds: 1200)));
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: T.ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: const Text('장바구니 담기',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      );
}
