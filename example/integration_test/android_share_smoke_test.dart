import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android share API smoke: capabilities, clipboard text/memory, fileExplorer, cleanup',
    (WidgetTester tester) async {
      final plugin = XueHuaNaviteShare.instance;

      final capabilities = await plugin.getCapabilities();
      expect(capabilities.platform.toLowerCase(), contains('android'));
      expect(capabilities.supportsSystemShareSheet, isTrue);
      expect(capabilities.supportsFileSharing, isTrue);
      expect(capabilities.supportsMultipleFiles, isTrue);
      expect(capabilities.supportsMemoryBytesSharing, isTrue);
      expect(capabilities.supportsTargetedServices, isTrue);
      expect(capabilities.availableServices, contains('systemClipboard'));
      expect(capabilities.availableServices, contains('mail'));
      expect(capabilities.availableServices, contains('messages'));
      expect(capabilities.availableServices, contains('systemSheet'));
      expect(capabilities.availableServices, contains('fileExplorer'));

      final canShareText = await plugin.canShare(
        const ShareParams(text: 'Android smoke test payload'),
      );
      expect(canShareText, isTrue);

      // Avoid systemSheet: Intent.createChooser is modal and blocks automation.
      final clipboardResult = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        const ShareParams(
          text: 'xue_hua_navite_share Android clipboard smoke test',
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
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
              fileName: 'android_smoke_mem.bin',
            ),
          ],
          title: 'Memory clipboard smoke',
        ),
      );
      expect(
        memoryResult.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final explorerResult = await plugin.shareToService(
        ShareTargetService.fileExplorer,
        ShareParams(
          items: <ShareItem>[
            ShareItem.memory(
              bytes: Uint8List.fromList(
                'android fileExplorer smoke'.codeUnits,
              ),
              fileName: 'android_smoke_reveal.txt',
              mimeType: 'text/plain',
            ),
          ],
          title: 'File explorer smoke',
        ),
      );
      expect(
        explorerResult.status,
        anyOf(
          ShareResultStatus.success,
          ShareResultStatus.unavailable,
          ShareResultStatus.fallbackExecuted,
        ),
      );

      final cleaned = await plugin.cleanupTempFiles();
      expect(cleaned, greaterThanOrEqualTo(0));
    },
  );
}
