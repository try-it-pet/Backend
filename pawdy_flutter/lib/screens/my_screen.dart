import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: T.paper,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('마이',
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: T.ink)),
                const Icon(Icons.settings_outlined, size: 21, color: T.ink),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('카카오로 로그인',
                          style: TextStyle(
                              color: T.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: T.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('둘러보기',
                        style: TextStyle(
                            color: T.sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DottedRegisterCard(),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: appState,
              builder: (_, __) => _statsCard(appState.likedIds.length),
            ),
            const SizedBox(height: 14),
            _menuCard(),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(int likes) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.line),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            _stat('0', '주문'),
            _divider(),
            _stat('$likes', '좋아요'),
            _divider(),
            _stat('0', 'AI 피팅'),
          ],
        ),
      );

  Widget _stat(String n, String l) => Expanded(
        child: Column(
          children: [
            Text(n,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: T.ink)),
            const SizedBox(height: 3),
            Text(l,
                style: const TextStyle(
                    fontSize: 11.5, color: T.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _divider() =>
      Container(width: 1, height: 30, color: T.soft);

  Widget _menuCard() {
    const items = [
      '주문 내역',
      '배송 현황',
      'AI 피팅 기록',
      '리뷰 관리',
      '쿠폰 · 포인트',
      '고객센터 · 설정',
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i < items.length - 1
                    ? const Border(bottom: BorderSide(color: Color(0xFFF1ECE6)))
                    : null,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(items[i],
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: T.ink)),
                  const Icon(Icons.chevron_right,
                      size: 20, color: Color(0xFFC4BDB3)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class DottedRegisterCard extends StatelessWidget {
  const DottedRegisterCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.line),
        ),
        alignment: Alignment.center,
        child: const Text('+ 우리 아이 프로필 등록하기',
            style: TextStyle(
                fontSize: 13.5, color: T.sub, fontWeight: FontWeight.w600)),
      );
}
