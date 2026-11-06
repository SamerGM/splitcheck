import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitcheck/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: SplitCheckApp()));
    expect(find.text('SplitCheck'), findsOneWidget);          // welcome screen
    await tester.pump(const Duration(seconds: 3));            // past the welcome screen
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplitCheckApp), findsOneWidget);
    // Let the chat's opening messages finish before the test ends.
    for (var i = 0; i < 10; i++) { await tester.pump(const Duration(milliseconds: 500)); }
  });
}
