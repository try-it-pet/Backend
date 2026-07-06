import 'package:flutter/material.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'home_screen.dart' show cats, productCardWithNav;

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String _cat = 'all';
  String _species = 'all';
  String _query = '';

  bool _matchesSpecies(Product p) =>
      _species == 'all' || p.species == _species || p.species == 'all';

  bool _matchesQuery(Product p) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    return p.name.toLowerCase().contains(q) || p.brand.toLowerCase().contains(q);
  }

  List<Product> _filtered() => appState.products
      .where((p) =>
          (_cat == 'all' || p.category == _cat) &&
          _matchesSpecies(p) &&
          _matchesQuery(p))
      .toList();

  @override
  Widget build(BuildContext context) {
    final items = _filtered();
    return Container(
      color: T.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchBar(),
            _catChips(),
            _speciesRow(items.length),
            Expanded(
              child: appState.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: T.accent, strokeWidth: 3))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          productCardWithNav(context, items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: T.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: T.muted2),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14, color: T.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '우리 아이 옷 찾기',
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: T.muted2,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _query = ''),
                  child: const Icon(Icons.close, size: 17, color: T.muted2),
                ),
            ],
          ),
        ),
      );

  Widget _catChips() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = cats[i];
            final on = _cat == c.key;
            return GestureDetector(
              onTap: () => setState(() => _cat = c.key),
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

  Widget _speciesRow(int count) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 4),
        child: Row(
          children: [
            for (final sp in const [
              ['all', '전체'],
              ['dog', '강아지'],
              ['cat', '고양이']
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _species = sp[0]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _species == sp[0] ? T.accentSoft : T.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: _species == sp[0] ? T.accent : T.line),
                    ),
                    child: Text(sp[1],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _species == sp[0] ? T.accent : T.sub)),
                  ),
                ),
              ),
            const Spacer(),
            Text('$count개',
                style: const TextStyle(
                    fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
