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
    expect(find.byType(SplitCheckApp), findsOneWidget);
  });
}
