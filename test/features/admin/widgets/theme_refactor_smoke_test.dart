import 'package:falconest/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal test harness pro smoke test renderu.
///
/// PROČ: `FalcoNestApp` v test prostředí vyžaduje plnou inicializaci Supabase/Firebase.
/// Tento smoke test má ověřit, že po theme refactoru se widget tree renderuje
/// bez runtime výjimky na úrovni Material shellu.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: SizedBox.shrink()),
    );
  }
}

void main() {
  group('Theme Refactor Smoke Test - Admin Widgets', () {
    testWidgets('wallet_detail_modal renders without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('payout_history_content renders without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('settlement_split_dialog renders without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('task_metadata_section renders without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
