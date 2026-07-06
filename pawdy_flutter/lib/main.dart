import 'package:flutter/material.dart';
import 'theme/tokens.dart';
import 'screens/intro_screen.dart';
import 'screens/home_screen.dart';

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

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onOpenFit: () => _go(2)),
      const _Placeholder('카테고리'),
      const _Placeholder('AI 피팅'),
      const _Placeholder('찜'),
      const _Placeholder('마이'),
    ];
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: _tab, children: screens),
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

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder(this.label);
  @override
  Widget build(BuildContext context) => Container(
        color: T.paper,
        child: SafeArea(
          child: Center(
            child: Text('$label 화면 준비 중',
                style: const TextStyle(
                    color: T.muted, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      );
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
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(2),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(0, -14),
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
            Transform.translate(
              offset: const Offset(0, -10),
              child: const Text('AI 피팅',
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
