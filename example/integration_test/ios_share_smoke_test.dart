import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

/// iOS Simulator–oriented smoke for the public share API.
///
/// Avoids modal `UIActivityViewController` / AirDrop / Messages / ReadingList.
/// Covers capabilities, canShare (text/uri/memory), clipboard text/URL/memory
/// (including multi memory items), and cleanupTempFiles idempotency.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS share API smoke: capabilities, clipboard text/uri/memory, cleanup',
    (WidgetTester tester) async {
      final plugin = XueHuaNaviteShare.instance;

      final capabilities = await plugin.getCapabilities();
      expect(capabilities.platform.toLowerCase(), contains('ios'));
      expect(capabilities.supportsSystemShareSheet, isTrue);
      expect(capabilities.supportsFileSharing, isTrue);
      expect(capabilities.supportsMultipleFiles, isTrue);
      expect(capabilities.supportsMemoryBytesSharing, isTrue);
      expect(capabilities.supportsTargetedServices, isTrue);
      expect(capabilities.supportsExcludedActivities, isTrue);
      expect(capabilities.supportsChosenTargetCallback, isTrue);
      expect(capabilities.availableServices, contains('systemClipboard'));
      expect(capabilities.availableServices, contains('mail'));
      expect(capabilities.availableServices, contains('systemSheet'));
      expect(capabilities.availableServices, contains('airDrop'));
      expect(capabilities.availableServices, contains('messages'));
      expect(capabilities.availableServices, contains('readingList'));

      expect(
        await plugin.canShare(
          const ShareParams(text: 'iOS smoke test payload'),
        ),
        isTrue,
      );
      expect(
        await plugin.canShare(
          ShareParams(uri: Uri.parse('https://example.com/ios-smoke')),
        ),
        isTrue,
      );
      expect(
        await plugin.canShare(
          ShareParams(
            items: <ShareItem>[
              ShareItem.memory(
                bytes: Uint8List.fromList(utf8.encode('canShare memory')),
                fileName: 'ios_canshare.txt',
                mimeType: 'text/plain',
              ),
            ],
          ),
        ),
        isTrue,
      );

      final clipboardText = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        const ShareParams(
          text: 'xue_hua_navite_share iOS clipboard smoke test',
          subject: 'Smoke test',
          title: 'Clipboard share',
        ),
      );
      expect(
        clipboardText.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final clipboardUri = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        ShareParams(
          uri: Uri.parse('https://github.com/Matkurban/xue_hua_navite_share'),
          title: 'URI clipboard smoke',
          text: 'Accompanying message for URL share',
          subject: 'URI subject',
        ),
      );
      expect(
        clipboardUri.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final clipboardMemory = await plugin.shareToService(
        ShareTargetService.systemClipboard,
        ShareParams(
          items: <ShareItem>[
            ShareItem.memory(
              bytes: Uint8List.fromList(<int>[9, 8, 7, 6]),
              fileName: 'ios_smoke_mem.bin',
            ),
            ShareItem.memory(
              bytes: Uint8List.fromList(utf8.encode('{"ok":true}')),
              fileName: 'ios_smoke_meta.json',
              mimeType: 'application/json',
            ),
          ],
          title: 'Memory clipboard smoke',
        ),
      );
      expect(
        clipboardMemory.status,
        anyOf(ShareResultStatus.success, ShareResultStatus.fallbackExecuted),
      );

      final cleaned = await plugin.cleanupTempFiles();
      expect(cleaned, greaterThanOrEqualTo(0));
      final cleanedAgain = await plugin.cleanupTempFiles();
      expect(cleanedAgain, greaterThanOrEqualTo(0));
    },
  );

  testWidgets(
    'iOS share API smoke: ShareParams validation rejects empty payload',
    (WidgetTester tester) async {
      expect(
        () => const ShareParams().validate(),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => XueHuaNaviteShare.instance.shareFiles(const <String>[]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => XueHuaNaviteShare.instance.shareMemoryFiles(const <ShareItem>[]),
        throwsA(isA<ArgumentError>()),
      );
    },
  );
}
