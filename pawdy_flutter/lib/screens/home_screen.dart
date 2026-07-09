import 'package:flutter/material.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/product_card.dart';
import 'detail_screen.dart';
import 'cart_screen.dart';

class _Cat {
  final String key;
  final String label;
  const _Cat(this.key, this.label);
}

const cats = [
  _Cat('all', '전체'),
  _Cat('care', '데일리케어'),
  _Cat('fashion', '패션·스타일'),
  _Cat('active', '액티브·아웃도어'),
  _Cat('wellness', '헬스·웰니스'),
  _Cat('home', '홈·인테리어'),
];

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenFit;
  final VoidCallback? onOpenSearch;
  const HomeScreen({super.key, this.onOpenFit, this.onOpenSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const petName = '초코';
  String _chip = 'all';


  List<Product> _homeSelection(List<Product> all) {
    if (_chip == 'all') {
      const ids = [0, 8, 15, 13, 2, 9];
      final byId = {for (final p in all) p.id: p};
      final picked = [for (final id in ids) if (byId[id] != null) byId[id]!];
      return picked.isNotEmpty ? picked.take(6).toList() : all.take(6).toList();
    }
    return all.where((p) => p.category == _chip).take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: T.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            _search(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _chips(),
                  _hero(),
                  _sectionHeader(),
                  _grid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Pawdy',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: T.ink)),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 5),
                    child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: T.accent, shape: BoxShape.circle)),
                  ),
                ],
              ),
              Row(
                children: [
                  _cartButton(),
                  const SizedBox(width: 4),
                  _profileAvatar(),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _cartButton() => GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen())),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 23, color: T.ink),
              if (appState.cartCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(
                        color: T.accent, shape: BoxShape.circle),
                    child: Text('${appState.cartCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                  ),
                ),
            ],
          ),
        ),
      );

  // 카카오 프로필 사진(동의 시) → 없으면 중립 실루엣
  Widget _profileAvatar() {
    final img = appState.user?.profileImage;
    return Container(
      width: 36,
      height: 36,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: T.soft, shape: BoxShape.circle),
      child: (img != null && img.isNotEmpty)
          ? Image.network(img,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_outline, size: 20, color: T.muted))
          : const Icon(Icons.person_outline, size: 20, color: T.muted),
    );
  }

  Widget _search() => GestureDetector(
        onTap: widget.onOpenSearch,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: T.line),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 20, color: T.muted2),
                SizedBox(width: 10),
                Expanded(
                  child: Text('우리 아이 옷 찾기',
                      style: TextStyle(
                          fontSize: 14.5,
                          color: T.muted2,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3)),
                ),
                Icon(Icons.photo_camera_outlined, size: 20, color: T.ink),
              ],
            ),
          ),
        ),
      );


  Widget _chips() => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = cats[i];
            final on = _chip == c.key;
            return GestureDetector(
              onTap: () => setState(() => _chip = c.key),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: on ? T.ink : T.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: on ? T.ink : T.line),
                ),
                child: Text(c.label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: on ? Colors.white : T.sub)),
              ),
            );
          },
        ),
      );

  Widget _hero() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
        child: GestureDetector(
          onTap: widget.onOpenFit,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: T.heroBg, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI 가상 피팅',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: T.heroLabel)),
                      const SizedBox(height: 11),
                      const Text('사진 한 장이면\n우리 아이가 입은\n모습이 바로 보여요',
                          style: TextStyle(
                              fontSize: 20,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: T.ink)),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                            color: T.ink,
                            borderRadius: BorderRadius.circular(999)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('지금 입혀보기',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward,
                                color: Colors.white, size: 15),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 104,
                  height: 128,
                  decoration: BoxDecoration(
                      color: T.soft, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: const Text('$petName 사진',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: T.muted2,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionHeader() => const Padding(
        padding: EdgeInsets.fromLTRB(22, 26, 22, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$petName한테 어울려요',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: T.ink)),
                SizedBox(height: 6),
                Text('AI가 $petName의 체형을 분석했어요',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: T.muted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            Text('더보기',
                style: TextStyle(
                    fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _grid() {
    if (appState.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
            child: CircularProgressIndicator(color: T.accent, strokeWidth: 3)),
      );
    }
    if (appState.error || appState.products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60, horizontal: 22),
        child: Center(
            child: Text('상품을 불러오지 못했어요',
                style: TextStyle(color: T.muted, fontWeight: FontWeight.w600))),
      );
    }
    final items = _homeSelection(appState.products);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.66,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => productCardWithNav(context, items[i]),
    );
  }
}

/// 공용: 카드 + 찜 토글 + 상세 이동.
Widget productCardWithNav(BuildContext context, Product p, {bool badge = true}) {
  return ProductCard(
    product: p,
    liked: appState.isLiked(p.id),
    showBadge: badge,
    onLike: () => appState.toggleLike(p.id),
    onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(product: p))),
  );
}
