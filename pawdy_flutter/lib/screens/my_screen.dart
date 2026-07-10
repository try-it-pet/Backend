import 'package:flutter/material.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../api/client.dart';

import 'pet_form_sheet.dart';
import 'settings_screen.dart';
import 'orders_screen.dart';
import 'my_reviews_screen.dart';
import 'fitting_history_screen.dart';
import 'coming_soon_screen.dart';
import 'shop_register_screen.dart';
import 'seller_dashboard_screen.dart';
import 'shipping_status_screen.dart';




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
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final user = appState.user;
        final pet = appState.firstPet;
        final likes = appState.likedIds.length;
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
                    const Text('마이페이지',
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
                if (user != null) ...[
                  if (appState.pets.isNotEmpty) ...[
                    for (final p in appState.pets) ...[
                      _petRow(context, p),
                      const SizedBox(height: 12),
                    ],
                    GestureDetector(
                      onTap: () => _openPetForm(context),
                      child: _dashedCard('+ 우리 아이 추가 등록하기'),
                    ),
                  ] else
                    GestureDetector(
                      onTap: () => _openPetForm(context),
                      child: _dashedCard('+ 우리 아이 프로필 등록하기'),
                    ),
                ] else
                  GestureDetector(
                    onTap: () => _openPetForm(context),
                    child: _dashedCard('로그인하면 우리 아이를 등록할 수 있어요'),
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
      },
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

  Widget _loginButtons(BuildContext context) => Column(
        children: [
          // 1. 카카오 로그인
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: appState.startKakaoLogin,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble, color: Color(0xFF3C1E1E), size: 16),
                  SizedBox(width: 8),
                  Text('카카오로 로그인',
                      style: TextStyle(
                          color: Color(0xFF3C1E1E),
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          // 2. 구글 로그인
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _showGoogleLoginMockDialog(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: T.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.g_mobiledata, color: T.ink, size: 28),
                  SizedBox(width: 2),
                  Text('Google로 로그인',
                      style: TextStyle(
                          color: T.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. 이메일 로그인 & 회원가입 가로 배치
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => _showEmailLoginBottomSheet(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: T.accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('이메일 로그인',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _showEmailRegisterBottomSheet(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: T.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('이메일 회원가입',
                        style: TextStyle(
                            color: T.sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. 둘러보기 (데모)
          TextButton(
            onPressed: () async {
              try {
                await appState.devLogin();
              } catch (e) {
                if (context.mounted) _toast(context, '$e');
              }
            },
            child: const Text(
              '게스트 모드로 둘러보기',
              style: TextStyle(
                  color: T.muted2,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );

  void _showGoogleLoginMockDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: '구글집사');
    final emailCtrl = TextEditingController(text: 'google_user_123');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Google 로그인 시뮬레이터', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: T.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('구글 로그인 API 연동용 개발자 시뮬레이터입니다. 구글 고유 ID와 닉네임을 설정해 로그인해보세요.', style: TextStyle(fontSize: 12, color: T.sub)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: '구글 고유 식별값 (ID Token 대용)',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '구글 닉네임',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: T.sub)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await appState.loginGoogle(emailCtrl.text.trim(), nickname: nameCtrl.text.trim());
              } catch (e) {
                if (context.mounted) _toast(context, '$e');
              }
            },
            child: const Text('로그인', style: TextStyle(color: T.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEmailLoginBottomSheet(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이메일 로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: T.ink)),
            const SizedBox(height: 18),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일 주소',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  final pass = passCtrl.text.trim();
                  if (email.isEmpty || pass.isEmpty) {
                    _toast(context, '이메일과 비밀번호를 입력해주세요.');
                    return;
                  }
                  Navigator.of(ctx).pop();
                  try {
                    await appState.loginEmail(email, pass);
                  } catch (e) {
                    if (context.mounted) _toast(context, '$e');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: T.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('로그인하기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailRegisterBottomSheet(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nickCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이메일 회원가입', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: T.ink)),
            const SizedBox(height: 18),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일 주소',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nickCtrl,
              decoration: const InputDecoration(
                labelText: '닉네임',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  final pass = passCtrl.text.trim();
                  final nick = nickCtrl.text.trim();
                  if (email.isEmpty || pass.isEmpty || nick.isEmpty) {
                    _toast(context, '모든 필드를 기입해 주세요.');
                    return;
                  }
                  Navigator.of(ctx).pop();
                  try {
                    await appState.registerEmail(email, pass, nick);
                    if (context.mounted) _toast(context, '회원가입 완료 및 자동 로그인되었습니다!');
                  } catch (e) {
                    if (context.mounted) _toast(context, '$e');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: T.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('가입 완료하기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _petRow(BuildContext context, Pet pet) {
    final hasImage = pet.image != null && pet.image!.isNotEmpty;
    final imageUrl = hasImage ? (pet.image!.startsWith('http') ? pet.image! : '$apiBase${pet.image!}') : null;
    final isActive = appState.activePet?.id == pet.id;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => appState.activePetId = pet.id,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: T.soft,
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(color: T.accent, width: 2)
                        : null,
                  ),
                  child: ClipOval(
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackAvatar(pet),
                          )
                        : _fallbackAvatar(pet),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(pet.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: T.ink)),
                          const SizedBox(width: 7),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: T.accentSoft,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: T.accent.withOpacity(0.3)),
                              ),
                              child: const Text(
                                '대표',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: T.accent,
                                ),
                              ),
                            ),
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
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(_measure(pet),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: T.muted,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        GestureDetector(
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: T.paper,
                title: const Text('우리 아이 정보 삭제', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: T.ink)),
                content: Text('${pet.name}의 프로필 정보를 삭제하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('취소', style: TextStyle(color: T.sub, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('삭제', style: TextStyle(color: T.accent, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await appState.removePet(pet.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${pet.name} 삭제되었습니다'), duration: const Duration(milliseconds: 1400)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e'), duration: const Duration(milliseconds: 1400)),
                  );
                }
              }
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: T.surface,
              shape: BoxShape.circle,
              border: Border.all(color: T.line),
            ),
            child: const Icon(Icons.delete_outline, size: 16, color: T.accent),
          ),
        ),

      ],
    );
  }

  Widget _fallbackAvatar(Pet pet) => Container(
        alignment: Alignment.center,
        color: T.soft,
        child: Text(pet.name.isNotEmpty ? pet.name.substring(0, 1) : '펫',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: T.sub)),
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

    final String sellerMenuTitle;
    final VoidCallback sellerMenuAction;

    if (!appState.loggedIn) {
      sellerMenuTitle = '판매자 등록 (상점 개설)';
      sellerMenuAction = () => _toast(context, '로그인하면 판매자로 등록할 수 있어요');
    } else if (appState.shop != null) {
      sellerMenuTitle = '내 상점 관리 (${appState.shop!.name})';
      sellerMenuAction = () => _push(context, const SellerDashboardScreen());
    } else {

      sellerMenuTitle = '판매자 등록 (상점 개설)';
      sellerMenuAction = () => _push(context, const ShopRegisterScreen());
    }

    final items = <(String, String, VoidCallback)>[
      ('주문 내역', orders > 0 ? '$orders건' : '', () => _openOrders(context)),
      ('배송 현황', '', () {
        if (!appState.loggedIn) {
          _toast(context, '로그인하면 배송 현황을 볼 수 있어요');
          return;
        }
        _push(context, const ShippingStatusScreen());
      }),
      ('AI 피팅 기록', '$fittings회', () {


        if (!appState.loggedIn) {
          _toast(context, '로그인하면 AI 피팅 기록을 볼 수 있어요');
          return;
        }
        _push(context, const FittingHistoryScreen());
      }),
      ('리뷰 관리', '', () {
        if (!appState.loggedIn) {
          _toast(context, '로그인하면 작성한 리뷰를 볼 수 있어요');
          return;
        }
        _push(context, const MyReviewsScreen());
      }),
      (sellerMenuTitle, '', sellerMenuAction),
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
