import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aalok_dashboard/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AalokDashboardApp());
    // Verify the app renders
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
