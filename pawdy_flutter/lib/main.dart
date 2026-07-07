import 'package:flutter/material.dart';
import 'theme/tokens.dart';
import 'state/app_state.dart';
import 'screens/intro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/fit_screen.dart';
import 'screens/category_screen.dart';
import 'screens/likes_screen.dart';
import 'screens/my_screen.dart';

void main() => runApp(const PawdyApp());

class PawdyApp extends StatelessWidget {
  const PawdyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pawdy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: T.paper,
        colorScheme: ColorScheme.fromSeed(
            seedColor: T.accent, primary: T.accent, surface: T.paper),
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;
  bool _intro = true;

  @override
  void initState() {
    super.initState();
    appState.load(); // 상품 카탈로그 1회 로드
    appState.initDeepLinks(); // 카카오 로그인 딥링크(pawdy://login?token=) 수신
  }

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          // 공유 상태(로그인·찜·장바구니 등) 변화 시 탭 내용 갱신.
          // ⚠️ const 위젯은 canonical 단일 인스턴스라 리빌드가 스킵됨 → non-const로 매 빌드 새 인스턴스 생성
          // (StatefulWidget 의 State 는 위치·타입이 같아 그대로 유지됨).
          body: AnimatedBuilder(
            animation: appState,
            builder: (_, __) => IndexedStack(
              index: _tab,
              children: [
                HomeScreen(onOpenFit: () => _go(2)),
                CategoryScreen(),
                FitScreen(),
                LikesScreen(),
                MyScreen(),
              ],
            ),
          ),
          bottomNavigationBar: _BottomBar(current: _tab, onTap: _go),
        ),
        if (_intro)
          Positioned.fill(
            child: IntroScreen(onFinish: () => setState(() => _intro = false)),
          ),
      ],
    );
  }
}

/// 하단 탭바 — 홈 / 카테고리 / AI피팅(가운데 코랄) / 찜 / 마이.
class _BottomBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(top: 11, bottom: bottomInset),
      decoration: const BoxDecoration(
        color: T.paper,
        border: Border(top: BorderSide(color: T.line)),
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            _tab(0, Icons.home_outlined, '홈'),
            _tab(1, Icons.grid_view, '카테고리'),
            _fitTab(),
            _tab(3, Icons.favorite_border, '찜'),
            _tab(4, Icons.person_outline, '마이'),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, IconData icon, String label) {
    final on = current == i;
    final color = on ? T.accent : const Color(0xFFB3ABA1);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _fitTab() {
    // Stack(Clip.none)으로 코랄 원이 탭바 위로 튀어나오게 — Column이면 높이 초과로 오버플로우
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(2),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -12,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: T.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: T.paper, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: T.accent.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.image_outlined,
                    color: Colors.white, size: 22),
              ),
            ),
            const Positioned(
              bottom: 6,
              child: Text('AI 피팅',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: T.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
