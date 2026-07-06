import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../theme/tokens.dart';
import '../widgets/product_card.dart';

class _Cat {
  final String key;
  final String label;
  const _Cat(this.key, this.label);
}

const _cats = [
  _Cat('all', '전체'),
  _Cat('care', '데일리케어'),
  _Cat('fashion', '패션·스타일'),
  _Cat('active', '액티브·아웃도어'),
  _Cat('wellness', '헬스·웰니스'),
  _Cat('home', '홈·인테리어'),
];

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenFit;
  const HomeScreen({super.key, this.onOpenFit});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const petName = '초코';
  String _chip = 'all';
  final Set<int> _liked = {};
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchProducts();
  }

  List<Product> _homeSelection(List<Product> all) {
    if (_chip == 'all') {
      // React 홈 큐레이션과 동일한 상품 id 우선, 없으면 앞에서 채움
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
              child: FutureBuilder<List<Product>>(
                future: _future,
                builder: (context, snap) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _chips(),
                      _hero(),
                      _sectionHeader(),
                      _grid(snap),
                      const SizedBox(height: 24),
                    ],
                  );
                },
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
              // 프로필: 비로그인/미동의 시 중립 실루엣 (카카오 로그인 붙으면 사진으로 교체)
              Container(
                width: 36,
                height: 36,
                decoration:
                    const BoxDecoration(color: T.soft, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, size: 20, color: T.muted),
              ),
            ],
          ),
        ),
      );

  Widget _search() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: T.muted2),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('우리 아이 옷 찾기',
                    style: TextStyle(
                        fontSize: 14.5,
                        color: T.muted2,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3)),
              ),
              const Icon(Icons.photo_camera_outlined, size: 20, color: T.ink),
            ],
          ),
        ),
      );

  Widget _chips() => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          itemCount: _cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = _cats[i];
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

  Widget _grid(AsyncSnapshot<List<Product>> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
            child: CircularProgressIndicator(color: T.accent, strokeWidth: 3)),
      );
    }
    if (snap.hasError || !snap.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60, horizontal: 22),
        child: Center(
          child: Text('상품을 불러오지 못했어요',
              style: TextStyle(color: T.muted, fontWeight: FontWeight.w600)),
        ),
      );
    }
    final items = _homeSelection(snap.data!);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final p = items[i];
        return ProductCard(
          product: p,
          liked: _liked.contains(p.id),
          onLike: () => setState(() =>
              _liked.contains(p.id) ? _liked.remove(p.id) : _liked.add(p.id)),
        );
      },
    );
  }
}
