import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_share_example/main.dart';

/// WidgetTester coverage of the example workbench on macOS.
///
/// Complements flutter_driver. Skips Share Text / Share Memory / Share URI that
/// open a modal NSSharingServicePicker (blocks automation until dismissed).
///
/// Uses [WidgetTester.pump] with fixed delays instead of [pumpAndSettle] because
/// focused TextField caret animations on macOS can prevent settling.
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
        matching: find.textContaining('macos'),
      ),
      findsOneWidget,
    );

    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('btn_cleanup_temp_body')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey<String>('btn_cleanup_temp_body')));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey<String>('result_cleaned_count')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('btn_share_files')),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey<String>('btn_share_files')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey<String>('result_status')), findsOneWidget);
    expect(find.textContaining('Status: error'), findsOneWidget);
  });
}
