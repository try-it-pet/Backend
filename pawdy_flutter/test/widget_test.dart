// Pawdy 앱 스모크 테스트 — 인트로에 브랜드 워드마크가 뜨는지 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pawdy/main.dart';

void main() {
  testWidgets('앱이 인트로 브랜드(Pawdy)를 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(const PawdyApp());
    await tester.pump(); // 첫 프레임(인트로)
    expect(find.text('Pawdy'), findsWidgets);
  });
}
