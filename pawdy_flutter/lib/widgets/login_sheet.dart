import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

/// 로그인 유도 바텀시트 — 로그인이 필요한 액션(담기·리뷰·피팅)에서 호출.
/// 로그인(둘러보기 포함) 성공 시 true. 카카오는 외부 브라우저→딥링크 복귀라 여기선 시트만 닫음.
Future<bool> showLoginSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LoginSheet(),
  );
  return result ?? appState.loggedIn;
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet();
  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: T.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
          22, 16, 22, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: T.line, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 18),
          const Text('로그인하고 계속해요',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: T.ink)),
          const SizedBox(height: 4),
          const Text('찜 · 장바구니 · AI 피팅 기록이 계정에 안전하게 저장돼요',
              style: TextStyle(
                  fontSize: 12.5, color: T.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      appState.startKakaoLogin();
                      Navigator.of(context).pop(false); // 딥링크 복귀로 로그인 완료
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('카카오로 3초 만에 로그인',
                  style: TextStyle(
                      color: T.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await appState.devLogin();
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (_) {
                        if (context.mounted) setState(() => _busy = false);
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: T.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(_busy ? '로그인 중…' : '로그인 없이 둘러보기',
                  style: const TextStyle(
                      color: T.sub, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
