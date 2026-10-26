import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows share API smoke: capabilities, clipboard, memory, files', (
    WidgetTester tester,
  ) async {
    final plugin = XueHuaNaviteShare.instance;

    final capabilities = await plugin.getCapabilities();
    expect(capabilities.platform.toLowerCase(), contains('windows'));
    expect(capabilities.supportsSystemShareSheet, isTrue);
    expect(capabilities.supportsFileSharing, isTrue);
    expect(capabilities.supportsMultipleFiles, isTrue);
    expect(capabilities.supportsMemoryBytesSharing, isTrue);
    expect(capabilities.supportsTargetedServices, isTrue);
    expect(capabilities.availableServices, contains('systemClipboard'));
    expect(capabilities.availableServices, contains('mail'));
    expect(capabilities.availableServices, contains('fileExplorer'));

    final canShareText = await plugin.canShare(
      const ShareParams(text: 'Windows smoke test payload'),
    );
    expect(canShareText, isTrue);

    final clipboardResult = await plugin.shareToService(
      ShareTargetService.systemClipboard,
      const ShareParams(
        text: 'xue_hua_navite_share Windows clipboard smoke test',
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
            fileName: 'windows_smoke_mem.bin',
          ),
        ],
        title: 'Memory clipboard smoke',
      ),
    );
    expect(
      memoryResult.status,
      anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
    );

    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}xue_hua_share_smoke.txt',
    );
    await tempFile.writeAsString('file share smoke from xue_hua_navite_share');

    final fileResult = await plugin.shareFiles(
      <String>[tempFile.path],
      text: 'Share file smoke',
      title: 'File share',
    );
    expect(
      fileResult.status,
      anyOf(
        ShareResultStatus.success,
        ShareResultStatus.fallbackExecuted,
        ShareResultStatus.dismissed,
      ),
    );

    final explorerResult = await plugin.shareToService(
      ShareTargetService.fileExplorer,
      ShareParams(
        items: <ShareItem>[
          ShareItem.file(tempFile.path, mimeType: 'text/plain'),
        ],
        title: 'Explorer reveal smoke',
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

    // systemSheet text should fallback to clipboard (not open mailto).
    final sheetResult = await plugin.shareText(
      'Windows systemSheet text should use clipboard fallback',
      subject: 'Sheet smoke',
      title: 'Sheet smoke',
      fallbackToClipboard: true,
    );
    expect(
      sheetResult.status,
      anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
    );

    final cleaned = await plugin.cleanupTempFiles();
    expect(cleaned, greaterThanOrEqualTo(0));

    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });
}