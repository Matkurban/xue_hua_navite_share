import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_share_example/main.dart';

void main() {
  testWidgets('Verify XueHuaShareExampleApp renders workbench', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const XueHuaShareExampleApp());

    expect(find.text('XueHua Native Share Workbench'), findsOneWidget);
    expect(find.text('Share Text'), findsOneWidget);
    expect(find.text('Share URI + Preview'), findsOneWidget);
    expect(
      find.text('Share In-Memory Files (JSON + PNG)'),
      findsOneWidget,
    );
  });
}
