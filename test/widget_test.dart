import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dompetai/presentation/navigation/main_navigation.dart';

void main() {
  setUpAll(() async {
    // Initialize date formatting for Indonesian locale for the tests
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('Dashboard UI renders successfully and can switch tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainNavigation(),
        ),
      ),
    );

    // Pump to initialize and handle microtasks/first frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that our Greeting exists.
    expect(find.textContaining("Ahmad!"), findsOneWidget);

    // Verify that bottom navigation items exist.
    expect(find.text("Beranda"), findsOneWidget);
    expect(find.text("Chat"), findsOneWidget);
    expect(find.text("Target"), findsOneWidget);
    expect(find.text("Utang"), findsOneWidget);

    // Tap the 'Chat' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that we are on the ChatScreen (DompetAI text is visible in AppBar)
    expect(find.text('DompetAI'), findsOneWidget);
  });
}
