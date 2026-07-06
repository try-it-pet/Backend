import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// 앱 진입 인트로(스플래시). 브랜드 노출 후 부드럽게 페이드아웃 → onFinish.
class IntroScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const IntroScreen({super.key, required this.onFinish});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter; // 마크/워드마크 등장
  late final AnimationController _pulse; // 코랄 도트 펄스
  double _opacity = 1;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _opacity = 0); // 페이드아웃 시작
    });
    Future.delayed(const Duration(milliseconds: 1950), () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    return Material(
      color: T.paper,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 420),
        child: Container(
          color: T.paper,
        alignment: Alignment.center,
        child: FadeTransition(
          opacity: curve,
          child: AnimatedBuilder(
            animation: curve,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (1 - curve.value) * 10),
              child: Transform.scale(scale: 0.94 + curve.value * 0.06, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: T.accent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: T.accent.withValues(alpha: 0.34),
                          blurRadius: 34,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  child: const Icon(Icons.image_outlined,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Pawdy',
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: T.ink)),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, bottom: 8),
                      child: ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.7).animate(
                            CurvedAnimation(
                                parent: _pulse, curve: Curves.easeInOut)),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: T.accent, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('우리 아이의 특별한 순간, AI로',
                    style: TextStyle(
                        fontSize: 13.5,
                        color: T.sub,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
