import 'package:flutter/material.dart';

/// Pawdy 디자인 토큰 — React design-system 의 T 객체와 동일 팔레트.
/// 철학: 미니멀, 그라데이션 없음, 액센트는 코랄 #E8674A 한 가지, AI는 텍스트 라벨로만.
class T {
  static const paper = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF1ECE6);
  static const heroBg = Color(0xFFEDE6DD);
  static const ink = Color(0xFF1A1714);
  static const sub = Color(0xFF6E665E);
  static const muted = Color(0xFF9B948C);
  static const muted2 = Color(0xFFA89F95);
  static const line = Color(0xFFECE7E1);
  static const accent = Color(0xFFE8674A);
  static const accentSoft = Color(0xFFFBEDE8);
  static const heroLabel = Color(0xFFA2693F);
}

/// 원화 표기 (1000단위 콤마)
String won(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
