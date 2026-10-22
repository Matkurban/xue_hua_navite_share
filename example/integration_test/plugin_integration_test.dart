import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getCapabilities & canShare integration test', (
    WidgetTester tester,
  ) async {
    final capabilities = await XueHuaNaviteShare.instance.getCapabilities();
    expect(capabilities.platform.isNotEmpty, isTrue);
    expect(capabilities.supportsSystemShareSheet, isTrue);

    final canShareText = await XueHuaNaviteShare.instance.canShare(
      const ShareParams(text: 'Integration test payload'),
    );
    expect(canShareText, isTrue);
  });
}
