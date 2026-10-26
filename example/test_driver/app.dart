import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_driver/driver_extension.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';
import 'package:xue_hua_navite_share_example/main.dart' as app;

/// Driver entrypoint for the example app.
///
/// Exposes a [DataHandler] so [FlutterDriver.requestData] can exercise native
/// share APIs without opening the blocking GTK AppChooser dialog.
Future<void> main() async {
  enableFlutterDriverExtension(
    handler: (String? message) async {
      final plugin = XueHuaNaviteShare.instance;
      switch (message) {
        case 'capabilities':
          final caps = await plugin.getCapabilities();
          return jsonEncode(caps.toMap());
        case 'can_share_text':
          final ok = await plugin.canShare(
            const ShareParams(text: 'flutter_driver canShare payload'),
          );
          return ok ? 'true' : 'false';
        case 'clipboard_text':
          final result = await plugin.shareToService(
            ShareTargetService.systemClipboard,
            const ShareParams(
              text: 'flutter_driver clipboard text smoke',
              subject: 'Driver clipboard',
              title: 'Clipboard share',
            ),
          );
          return jsonEncode(result.toMap());
        case 'clipboard_memory':
          final result = await plugin.shareToService(
            ShareTargetService.systemClipboard,
            ShareParams(
              items: <ShareItem>[
                ShareItem.memory(
                  bytes: Uint8List.fromList(<int>[9, 8, 7, 6]),
                  fileName: 'driver_mem.bin',
                ),
              ],
              title: 'Memory clipboard',
            ),
          );
          return jsonEncode(result.toMap());
        case 'file_explorer':
          // Creates a temp file then reveals via GIO / FileManager1 (non-modal).
          final result = await plugin.shareToService(
            ShareTargetService.fileExplorer,
            ShareParams(
              items: <ShareItem>[
                ShareItem.memory(
                  bytes: Uint8List.fromList(
                    utf8.encode('flutter_driver fileExplorer smoke'),
                  ),
                  fileName: 'driver_reveal.txt',
                  mimeType: 'text/plain',
                ),
              ],
              title: 'File explore',
            ),
          );
          return jsonEncode(result.toMap());
        case 'cleanup':
          final count = await plugin.cleanupTempFiles();
          return '$count';
        default:
          return 'unknown:$message';
      }
    },
  );
  app.main();
}
