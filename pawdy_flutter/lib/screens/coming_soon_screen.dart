import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// 백엔드가 아직 없는 메뉴(배송·리뷰·쿠폰 등)를 위한 공용 "준비 중" 화면.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const ComingSoonScreen({
    super.key,
    required this.title,
    this.subtitle = '곧 만나요',
    this.icon = Icons.hourglass_empty,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            PawdyBar(title: title),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                          color: T.soft,
                          borderRadius: BorderRadius.circular(20)),
                      child: Icon(icon, color: T.muted2, size: 30),
                    ),
                    const SizedBox(height: 18),
                    Text('$title 준비 중이에요',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.ink)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13,
                            color: T.muted,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공용 상단바 — 뒤로가기 + 타이틀.
class PawdyBar extends StatelessWidget {
  final String title;
  const PawdyBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: T.ink),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: T.ink)),
        ],
      ),
    );
  }
}
