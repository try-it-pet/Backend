import 'package:flutter/material.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'pet_form_sheet.dart';
import 'settings_screen.dart';
import 'orders_screen.dart';
import 'coming_soon_screen.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  String _speciesKo(String s) =>
      const {'dog': '강아지', 'cat': '고양이', 'rabbit': '토끼'}[s] ?? s;

  String _measure(Pet p) {
    final parts = [
      if (p.chestCm != null) '가슴 ${p.chestCm}cm',
      if (p.neckCm != null) '목 ${p.neckCm}cm',
      if (p.backCm != null) '등길이 ${p.backCm}cm',
    ];
    return parts.isEmpty ? '신체 치수 미등록' : parts.join(' · ');
  }

  void _openPetForm(BuildContext context) {
    if (!appState.loggedIn) {
      _toast(context, '로그인하면 우리 아이를 등록할 수 있어요');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PetFormSheet(),
    );
  }

  void _toast(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)));

  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    final pet = appState.firstPet;
    final likes = appState.stats?.likes ?? appState.likedIds.length;
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
                GestureDetector(
                  onTap: () => _push(context, const SettingsScreen()),
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.settings_outlined,
                      size: 21, color: T.ink),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (user != null)
              _loggedInRow(context, user)
            else
              _loginButtons(context),
            const SizedBox(height: 16),
            if (pet != null)
              _petRow(context, pet)
            else
              GestureDetector(
                onTap: () => _openPetForm(context),
                child: _dashedCard(user != null
                    ? '+ 우리 아이 프로필 등록하기'
                    : '로그인하면 우리 아이를 등록할 수 있어요'),
              ),
            const SizedBox(height: 16),
            _statsCard(appState.stats?.orders ?? 0, likes,
                appState.stats?.fittings ?? 0),
            const SizedBox(height: 14),
            _menuCard(context),
          ],
        ),
      ),
    );
  }

  Widget _loggedInRow(BuildContext context, User user) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${user.nickname}님 · ${user.isKakao ? '카카오' : '체험'}',
              style: const TextStyle(
                  fontSize: 13, color: T.sub, fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: appState.logout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: T.line),
              ),
              child: const Text('로그아웃',
                  style: TextStyle(
                      fontSize: 12, color: T.sub, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );

  Widget _loginButtons(BuildContext context) => Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: appState.startKakaoLogin,
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
              onPressed: () async {
                try {
                  await appState.devLogin();
                } catch (e) {
                  if (context.mounted) _toast(context, '$e');
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: T.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('둘러보기',
                  style: TextStyle(
                      color: T.sub, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );

  Widget _petRow(BuildContext context, Pet pet) => Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration:
                const BoxDecoration(color: T.soft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(pet.name.isNotEmpty ? pet.name.substring(0, 1) : '펫',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: T.sub)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(pet.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: T.ink)),
                  const SizedBox(width: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: T.soft, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                        [
                          _speciesKo(pet.species),
                          if (pet.weightKg != null) '${pet.weightKg}kg'
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: T.sub)),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(_measure(pet),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: T.muted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openPetForm(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: T.surface,
                shape: BoxShape.circle,
                border: Border.all(color: T.line),
              ),
              child: const Icon(Icons.add, size: 16, color: T.sub),
            ),
          ),
        ],
      );

  Widget _dashedCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.line),
        ),
        alignment: Alignment.center,
        child: Text(text,
            style: const TextStyle(
                fontSize: 13.5, color: T.sub, fontWeight: FontWeight.w600)),
      );

  Widget _statsCard(int orders, int likes, int fittings) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.line),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            _stat('$orders', '주문'),
            _divider(),
            _stat('$likes', '좋아요'),
            _divider(),
            _stat('$fittings', 'AI 피팅'),
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

  Widget _divider() => Container(width: 1, height: 30, color: T.soft);

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openOrders(BuildContext context) {
    if (!appState.loggedIn) {
      _toast(context, '로그인하면 주문 내역을 볼 수 있어요');
      return;
    }
    _push(context, const OrdersScreen());
  }

  Widget _menuCard(BuildContext context) {
    final orders = appState.stats?.orders ?? 0;
    final fittings = appState.stats?.fittings ?? 0;
    final items = <(String, String, VoidCallback)>[
      ('주문 내역', orders > 0 ? '$orders건' : '', () => _openOrders(context)),
      ('배송 현황', '', () => _push(context,
          const ComingSoonScreen(title: '배송 현황', icon: Icons.local_shipping_outlined))),
      ('AI 피팅 기록', '$fittings회', () => _push(context, const ComingSoonScreen(
          title: 'AI 피팅 기록',
          subtitle: '생성한 이미지를 모아보는 기능을 준비 중이에요',
          icon: Icons.auto_awesome))),
      ('리뷰 관리', '', () => _push(context,
          const ComingSoonScreen(title: '리뷰 관리', icon: Icons.rate_review_outlined))),
      ('쿠폰 · 포인트', '', () => _push(context,
          const ComingSoonScreen(title: '쿠폰 · 포인트', icon: Icons.confirmation_number_outlined))),
      ('고객센터 · 설정', '', () => _push(context, const SettingsScreen())),
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
            InkWell(
              onTap: items[i].$3,
              child: Container(
                decoration: BoxDecoration(
                  border: i < items.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF1ECE6)))
                      : null,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(items[i].$1,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: T.ink)),
                    Row(
                      children: [
                        if (items[i].$2.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(items[i].$2,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: T.muted,
                                    fontWeight: FontWeight.w600)),
                          ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: Color(0xFFC4BDB3)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
