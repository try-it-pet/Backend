import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;

// 빌드 식별 태그 — 빌드 시 --dart-define=BUILD_TAG=... 로 주입. 최신 APK 설치 확인용.
const String _buildTag = String.fromEnvironment('BUILD_TAG', defaultValue: 'dev');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Generations? _gen;

  @override
  void initState() {
    super.initState();
    if (appState.loggedIn) {
      Api.fetchGenerations().then((g) {
        if (mounted) setState(() => _gen = g);
      });
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1300)));

  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            const PawdyBar(title: '설정'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                children: [
                  if (user != null) ...[
                    _card([
                      _row('계정', '${user.nickname}님'),
                      _row('로그인 방식', user.isKakao ? '카카오' : '체험(둘러보기)'),
                    ]),
                    const SizedBox(height: 14),
                    _generationsCard(),
                    const SizedBox(height: 14),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _card([_row('계정', '로그인 안 됨')]),
                    ),
                  _card([
                    _tap('문의하기', () => _toast('문의 기능은 준비 중이에요')),
                    _tap('이용약관 · 개인정보', () => _toast('준비 중이에요')),
                    _row('앱 버전', '1.0.0 ($_buildTag)'),
                  ]),
                  const SizedBox(height: 14),
                  if (user != null)
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          appState.logout();
                          Navigator.of(context).maybePop();
                          _toast('로그아웃됐어요');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: T.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('로그아웃',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: T.sub)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generationsCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: T.accentSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: T.accent, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('AI 생성 잔여 횟수',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.ink)),
            ),
            Text(_gen?.label ?? '…',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: T.accent)),
          ],
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: T.ink)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, color: T.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tap(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: T.ink)),
              const Icon(Icons.chevron_right,
                  size: 20, color: Color(0xFFC4BDB3)),
            ],
          ),
        ),
      );
}
