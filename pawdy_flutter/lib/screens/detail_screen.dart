import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/login_sheet.dart';
import 'review_write_sheet.dart';
import 'fit_screen.dart';

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

/// 별점 표시(정수 반올림 기준 채움).
class Stars extends StatelessWidget {
  final double rating;
  final double size;
  const Stars(this.rating, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) {
    final full = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= full ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size, color: T.accent),
      ],
    );
  }
}

class DetailScreen extends StatefulWidget {
  final Product product;
  const DetailScreen({super.key, required this.product});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ProductReviews _reviews = const ProductReviews();
  bool _loadingReviews = true;
  String? _selectedSize;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    final sizes = product.sizes;
    if (sizes != null && sizes.isNotEmpty) {
      _selectedSize = sizes.contains('M') ? 'M' : sizes.first;
    }
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final r = await Api.fetchProductReviews(product.id);
      if (mounted) setState(() { _reviews = r; _loadingReviews = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _writeReview() async {
    if (!appState.loggedIn) {
      await showLoginSheet(context);
      if (!appState.loggedIn) return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ReviewWriteSheet(productId: product.id, productName: product.name),
    );
    if (ok == true) _loadReviews();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1300)));

  @override
  Widget build(BuildContext context) {
    final img = Api.imageUrl(product);
    final copy = _detailCopy[product.category] ?? _detailCopy['fashion']!;
    final sizes = product.sizes;
    final sizeText =
        sizes != null && sizes.isNotEmpty ? sizes.join(' · ') : 'Free (단일 사이즈)';
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
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 17, color: T.ink),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(product.brand,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: T.muted2,
                                  fontWeight: FontWeight.w700)),
                          if (_reviews.count > 0)
                            Row(children: [
                              Stars(_reviews.average, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                  '${_reviews.average}  (${_reviews.count})',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: T.sub,
                                      fontWeight: FontWeight.w600)),
                            ]),
                        ],
                      ),
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
                        Expanded(
                            child: _spec(copy[1] as String, copy[2] as String)),
                        const SizedBox(width: 10),
                        Expanded(child: _spec('사이즈 범위', sizeText)),
                      ]),
                      const SizedBox(height: 12),
                      // 남은 재고 수량 노출
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: product.isOutOfStock ? T.accentSoft : T.soft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product.isOutOfStock ? '상태: 품절' : '남은 재고',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: product.isOutOfStock ? T.accent : T.sub,
                              ),
                            ),
                            Text(
                              product.isOutOfStock ? '구매 불가' : '${product.stock ?? 0}개',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: product.isOutOfStock ? T.accent : T.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (product.fittable) _fitCta(),
                      if (sizes != null && sizes.isNotEmpty) _sizeSelector(sizes),
                    ],
                  ),
                ),
                _reviewsSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          _bottomBar(context),
        ],
      ),
    );
  }

  Widget _fitCta() {
    final isHome = product.category == 'home';
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GestureDetector(
        onTap: () {
          if (product.isOutOfStock) {
            _snack('품절된 상품은 AI 피팅을 이용할 수 없습니다');
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FitScreen(initialProductId: product.id)));
        },
        child: Opacity(
          opacity: product.isOutOfStock ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: T.accentSoft, borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.auto_awesome, color: T.accent, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isHome ? '우리 집에 배치해보기' : '우리 아이한테 입혀보기',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: T.ink)),
                      const SizedBox(height: 2),
                      Text(isHome ? 'AI가 우리 집 사진에 배치해드려요' : 'AI가 우리 아이 사진에 바로 입혀드려요',
                          style: const TextStyle(
                              fontSize: 12,
                              color: T.muted,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 19, color: Color(0xFFC4BDB3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeSelector(List<String> sizes) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('사이즈',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
              Text('AI 추천 ${_selectedSize ?? ''}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: T.accent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in sizes)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: s == sizes.last ? 0 : 9),
                    child: GestureDetector(
                      onTap: product.isOutOfStock ? null : () => setState(() => _selectedSize = s),
                      child: Opacity(
                        opacity: product.isOutOfStock ? 0.4 : 1.0,
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedSize == s ? T.ink : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _selectedSize == s ? T.ink : T.line),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedSize == s ? Colors.white : T.sub)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showMatchScoreGuide,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: T.soft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined, size: 20, color: T.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'AI 매치 점수 ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: T.ink),
                            ),
                            Text(
                              '${product.fit}%',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: T.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _getFitDescription(product.fit),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: T.sub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.info_outline, size: 16, color: T.muted2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFitDescription(int fit) {
    if (fit >= 93) return '우리 아이에게 완벽하게 어울리고 편안한 추천 핏이에요.';
    if (fit >= 85) return '약간의 여유(3~5cm)가 있어 활동하기 편안한 핏이에요.';
    if (fit >= 70) return '슬림하고 딱 맞는 핏이에요. 상세 치수를 확인해 주세요.';
    return '치수 차이가 있어 착용 시 다소 낄 수 있어요.';
  }

  void _showMatchScoreGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: T.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: T.accent, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'AI 매치 점수 산출 안내',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: T.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '포디의 AI는 등록된 반려동물의 고유 신체 데이터(목 둘레, 가슴 둘레, 등 길이)와 해당 상품의 실측 사이즈 표를 정밀 비교 분석하여 최적의 적합도를 백분율로 산출합니다.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: T.sub,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _guideRow(
              title: '93% ~ 100% : 완벽한 매치',
              desc: '반려동물의 체형과 가슴/목둘레 오차가 2cm 이내로 매우 편안하고 완벽하게 맞아떨어지는 최적의 추천 사이즈입니다.',
              color: T.accent,
            ),
            const SizedBox(height: 16),
            _guideRow(
              title: '85% ~ 92% : 여유로운 매치',
              desc: '약 3~5cm 정도의 활동성 여유분이 확보되어, 격렬한 야외 활동이나 산책 시에도 아이가 매우 편안해합니다.',
              color: const Color(0xFFE2A54A),
            ),
            const SizedBox(height: 16),
            _guideRow(
              title: '70% ~ 84% : 슬림/타이트 매치',
              desc: '체형에 딱 맞아떨어지는 핏으로, 신축성이 없는 탄탄한 면 원단 등은 착용 시 가슴 부분이 다소 조이거나 꽉 낄 수 있습니다.',
              color: const Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            _guideRow(
              title: '70% 미만 : 신중한 구매 요망',
              desc: '신체 사이즈보다 제품이 작거나 5cm 이상 큽니다. 착용 및 고정이 불가능할 수 있으므로 다른 사이즈나 제품을 권장합니다.',
              color: const Color(0xFFDC2626),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideRow({required String title, required String desc, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: T.sub,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _reviewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('리뷰 ${_reviews.count}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
              GestureDetector(
                onTap: _writeReview,
                child: Row(children: const [
                  Icon(Icons.edit_outlined, size: 15, color: T.accent),
                  SizedBox(width: 4),
                  Text('리뷰 쓰기',
                      style: TextStyle(
                          fontSize: 13,
                          color: T.accent,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingReviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: T.accent, strokeWidth: 2.5))),
            )
          else if (_reviews.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.line)),
              alignment: Alignment.center,
              child: const Text('첫 리뷰를 남겨보세요',
                  style: TextStyle(
                      fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
            )
          else
            ..._reviews.items.map(_reviewCard),
        ],
      ),
    );
  }

  Widget _reviewCard(Review r) {
    final hasImage = r.image != null && r.image!.isNotEmpty;
    final imageUrl = hasImage
        ? (r.image!.startsWith('http') ? r.image! : '$apiBase${r.image!}')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Stars(r.rating.toDouble(), size: 13),
                const SizedBox(width: 7),
                Text(r.nickname,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: T.ink)),
              ]),
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
          if (hasImage) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showFullImage(imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


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
                  onPressed: product.isOutOfStock ? null : () async {
                    if (!appState.loggedIn) {
                      await showLoginSheet(context);
                      if (!appState.loggedIn) return;
                    }
                    final size = _selectedSize ?? 'Free';
                    try {
                      await appState.addToCart(product.id, size);
                      _snack('장바구니에 담았어요');
                    } catch (e) {
                      _snack('$e');
                    }
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: product.isOutOfStock ? T.muted : T.ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: Text(product.isOutOfStock ? '품절된 상품' : '장바구니 담기',
                      style: const TextStyle(
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
