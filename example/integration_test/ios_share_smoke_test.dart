import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS share API smoke: capabilities, clipboard text/memory, cleanup',
    (WidgetTester tester) async {
      final plugin = XueHuaNaviteShare.instance;

      final capabilities = await plugin.getCapabilities();
      expect(capabilities.platform.toLowerCase(), contains('ios'));
      expect(capabilities.supportsSystemShareSheet, isTrue);
      expect(capabilities.supportsFileSharing, isTrue);
      expect(capabilities.supportsMemoryBytesSharing, isTrue);
      expect(capabilities.supportsTargetedServices, isTrue);
      expect(capabilities.availableServices, contains('systemClipboard'));
      expect(capabilities.availableServices, contains('mail'));
      expect(capabilities.availableServices, contains('systemSheet'));

      final canShareText = await plugin.canShare(
        const ShareParams(text: 'iOS smoke test payload'),
      );
      expect(canShareText, isTrue);

      // Avoid systemSheet: UIActivityViewController is modal.
      final clipboardResult = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        const ShareParams(
          text: 'xue_hua_navite_share iOS clipboard smoke test',
          subject: 'Smoke test',
          title: 'Clipboard share',
        ),
      );
      expect(
        clipboardResult.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final memoryResult = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        ShareParams(
          items: <ShareItem>[
            ShareItem.memory(
              bytes: Uint8List.fromList(<int>[9, 8, 7, 6]),
              fileName: 'ios_smoke_mem.bin',
            ),
          ],
          title: 'Memory clipboard smoke',
        ),
      );
      expect(
        memoryResult.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final cleaned = await plugin.cleanupTempFiles();
      expect(cleaned, greaterThanOrEqualTo(0));
    },
  );
}
