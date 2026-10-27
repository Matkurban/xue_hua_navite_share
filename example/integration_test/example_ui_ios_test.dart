import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_share_example/main.dart';

/// WidgetTester coverage of the example workbench on iOS.
///
/// Complements flutter_driver / ios_share_smoke_test. Skips Share Text /
/// Share Memory / Share URI that open a modal UIActivityViewController.
///
/// Uses AppBar cleanup (always on-screen) instead of the ListView body button,
/// because iPhone viewport height can leave the body button off-screen even
/// after [scrollUntilVisible]. Fixed [pump] delays avoid caret settle hangs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example UI: capabilities, cleanup, empty files', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const XueHuaShareExampleApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey<String>('app_bar_title')), findsOneWidget);

    final platformChip = find.byKey(const ValueKey<String>('chip_platform'));
    expect(platformChip, findsOneWidget);
    expect(
      find.descendant(
        of: platformChip,
        matching: find.textContaining('ios'),
      ),
      findsOneWidget,
    );

    // AppBar cleanup is always hittable on iPhone-sized screens.
    await tester.tap(find.byKey(const ValueKey<String>('btn_cleanup_temp')));
    await tester.pump(const Duration(seconds: 1));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('result_cleaned_count')),
      300,
      scrollable: scrollable,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('result_cleaned_count')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('btn_share_files')),
      -200,
      scrollable: scrollable,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey<String>('btn_share_files')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey<String>('btn_share_files')));
    await tester.pump(const Duration(seconds: 1));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('result_status')),
      200,
      scrollable: scrollable,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey<String>('result_status')), findsOneWidget);
    expect(find.textContaining('Status: error'), findsOneWidget);
  });
}
