import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_share_example/main.dart';

void main() {
  testWidgets('Verify XueHuaShareExampleApp renders workbench', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const XueHuaShareExampleApp());
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('app_bar_title')), findsOneWidget);
    expect(find.text('XueHua Native Share Workbench'), findsOneWidget);
    expect(find.text('Host Platform Capabilities'), findsOneWidget);

    // Share action buttons are below the fold in a lazy ListView.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('btn_share_text')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey<String>('btn_share_text')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('btn_share_uri')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('btn_share_memory')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('btn_cleanup_temp_body')),
      findsOneWidget,
    );
  });
}
