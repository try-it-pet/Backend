import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'home_screen.dart' show productCardWithNav;

class LikesScreen extends StatelessWidget {
  const LikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = appState.liked;
    return Container(
      color: T.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('찜',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: T.ink)),
                  Text('${items.length}개 저장됨',
                      style: const TextStyle(
                          fontSize: 13,
                          color: T.muted,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                                color: T.soft,
                                borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.favorite_border,
                                color: Color(0xFFC4BDB3), size: 28),
                          ),
                          const SizedBox(height: 18),
                          const Text('아직 찜한 상품이 없어요',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: T.muted,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          productCardWithNav(context, items[i], badge: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
