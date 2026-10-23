import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Linux share API smoke: capabilities, clipboard, fileExplorer, cleanup',
    (WidgetTester tester) async {
      final plugin = XueHuaNaviteShare.instance;

      final capabilities = await plugin.getCapabilities();
      expect(capabilities.platform.toLowerCase(), contains('linux'));
      expect(capabilities.supportsSystemShareSheet, isTrue);
      expect(capabilities.supportsFileSharing, isTrue);
      expect(capabilities.supportsMultipleFiles, isTrue);
      expect(capabilities.supportsMemoryBytesSharing, isTrue);
      expect(capabilities.supportsTargetedServices, isTrue);
      expect(capabilities.availableServices, contains('systemClipboard'));
      expect(capabilities.availableServices, contains('mail'));
      expect(capabilities.availableServices, contains('fileExplorer'));

      final canShareText = await plugin.canShare(
        const ShareParams(text: 'Linux smoke test payload'),
      );
      expect(canShareText, isTrue);

      // Clipboard path is non-modal and safe for CI / headless automation.
      final clipboardResult = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        const ShareParams(
          text: 'xue_hua_navite_share Linux clipboard smoke test',
          subject: 'Smoke test',
          title: 'Clipboard share',
        ),
      );
      expect(
        clipboardResult.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      // Avoid shareFiles(): Linux opens a blocking GTK AppChooserDialog.
      // fileExplorer reveals via GIO and returns without a modal chooser.
      final tempFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}xue_hua_share_linux_smoke.txt',
      );
      await tempFile.writeAsString('file share smoke from xue_hua_navite_share');

      final fileExplorerResult = await plugin.shareToService(
        ShareTargetService.fileExplorer,
        ShareParams(
          items: <ShareItem>[ShareItem.file(tempFile.path)],
          text: 'Share file smoke',
          title: 'File explore',
        ),
      );
      expect(
        fileExplorerResult.status,
        anyOf(
          ShareResultStatus.success,
          ShareResultStatus.unavailable,
          ShareResultStatus.fallbackExecuted,
        ),
      );

      // Memory bytes → temp file path, then clipboard (still non-modal).
      final memoryResult = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        ShareParams(
          items: <ShareItem>[
            ShareItem.memory(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              fileName: 'smoke_mem.bin',
            ),
          ],
          title: 'Memory clipboard',
        ),
      );
      expect(
        memoryResult.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final cleaned = await plugin.cleanupTempFiles();
      expect(cleaned, greaterThanOrEqualTo(0));

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    },
  );
}
