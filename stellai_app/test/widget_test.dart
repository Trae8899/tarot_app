import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stellai_app/main.dart';

void main() {
  testWidgets('앱 초기 로딩 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StellaiApp()));

    expect(find.text('Stellai Tarot Library'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
