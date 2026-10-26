import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_share_example/main.dart';

/// WidgetTester coverage of the example workbench on Linux.
///
/// Complements flutter_driver. Skips Share Memory / systemSheet file flows that
/// open a blocking GTK AppChooserDialog.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example UI: capabilities, cleanup, share text, empty files', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const XueHuaShareExampleApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey<String>('app_bar_title')), findsOneWidget);

    final platformChip = find.byKey(const ValueKey<String>('chip_platform'));
    expect(platformChip, findsOneWidget);
    expect(
      find.descendant(of: platformChip, matching: find.textContaining('linux')),
      findsOneWidget,
    );

    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('btn_cleanup_temp_body')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey<String>('btn_cleanup_temp_body')));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('result_status')), findsOneWidget);
    expect(find.textContaining('Status: error'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('btn_share_text')),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey<String>('btn_share_text')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final statusText = tester
        .widget<Text>(find.byKey(const ValueKey<String>('result_status')))
        .data!;
    expect(
      statusText.contains('success') || statusText.contains('fallbackExecuted'),
      isTrue,
      reason: statusText,
    );
  });
}
