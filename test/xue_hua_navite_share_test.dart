import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share_method_channel.dart';

class MockXueHuaNaviteSharePlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteSharePlatform {
  ShareParams? lastShareParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    params.validate();
    lastShareParams = params;
    return ShareResult(
      status: ShareResultStatus.success,
      selectedActivityType: params.targetService.wireName,
      message: 'Mock share completed.',
    );
  }

  @override
  Future<bool> canShare(ShareParams params) async {
    params.validate();
    return params.resolvedItems.isNotEmpty;
  }

  @override
  Future<SharePlatformCapabilities> getCapabilities() async {
    return const SharePlatformCapabilities(
      platform: 'macos',
      supportsSystemShareSheet: true,
      supportsFileSharing: true,
      supportsMultipleFiles: true,
      supportsMemoryBytesSharing: true,
      supportsTargetedServices: true,
      supportsAnchorPopover: true,
      supportsExcludedActivities: true,
      supportsChosenTargetCallback: true,
      availableServices: <String>[
        'com.apple.share.AirDrop.send',
        'systemClipboard',
      ],
    );
  }

  @override
  Future<int> cleanupTempFiles() async => 3;
}

void main() {
  final XueHuaNaviteSharePlatform initialPlatform =
      XueHuaNaviteSharePlatform.instance;

  test('$MethodChannelXueHuaNaviteShare is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteShare>());
  });

  group('XueHuaNaviteShare API tests', () {
    late XueHuaNaviteShare plugin;
    late MockXueHuaNaviteSharePlatform mockPlatform;

    setUp(() {
      plugin = XueHuaNaviteShare.instance;
      mockPlatform = MockXueHuaNaviteSharePlatform();
      XueHuaNaviteSharePlatform.instance = mockPlatform;
    });

    test('shareText delegates to platform with text item and metadata', () async {
      final anchor = ShareAnchorRect.fromRect(
        const Rect.fromLTWH(20, 40, 120, 44),
      );
      final result = await plugin.shareText(
        'Hello XueHua Native Share!',
        subject: 'Greeting Subject',
        title: 'Share Greeting',
        anchorRect: anchor,
        excludedActivityTypes: const <ShareActivityType>[
          ShareActivityType.print,
        ],
      );

      expect(result.isSuccess, isTrue);
      expect(result.status, ShareResultStatus.success);
      expect(mockPlatform.lastShareParams?.text, 'Hello XueHua Native Share!');
      expect(mockPlatform.lastShareParams?.subject, 'Greeting Subject');
      expect(mockPlatform.lastShareParams?.anchorRect?.x, 20);
      expect(
        mockPlatform.lastShareParams?.excludedActivityTypes,
        contains(ShareActivityType.print),
      );
    });

    test('shareUri builds URL item and preview thumbnail metadata', () async {
      final thumbnail = Uint8List.fromList(<int>[137, 80, 78, 71]);
      final result = await plugin.shareUri(
        Uri.parse('https://github.com/Matkurban/xue_hua_navite_share'),
        title: 'GitHub Repository',
        message: 'Check out this 6-platform Flutter share plugin!',
        previewThumbnail: thumbnail,
      );

      expect(result.isSuccess, isTrue);
      expect(
        mockPlatform.lastShareParams?.uri.toString(),
        'https://github.com/Matkurban/xue_hua_navite_share',
      );
      expect(mockPlatform.lastShareParams?.previewThumbnail, thumbnail);
    });

    test('shareFiles infers MIME types and validates non-empty paths', () async {
      final result = await plugin.shareFiles(
        <String>['/tmp/photo.png', '/tmp/report.pdf'],
        text: 'Attached files',
      );

      expect(result.isSuccess, isTrue);
      final items = mockPlatform.lastShareParams!.items;
      expect(items.length, 2);
      expect(items[0].mimeType, 'image/png');
      expect(items[0].type, ShareItemType.image);
      expect(items[1].mimeType, 'application/pdf');
      expect(items[1].type, ShareItemType.file);
    });

    test('shareMemoryFiles shares in-memory bytes and cleans up temp files', () async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final item = ShareItem.memory(
        bytes: bytes,
        fileName: 'sample.json',
      );
      expect(item.mimeType, 'application/json');

      final result = await plugin.shareMemoryFiles(<ShareItem>[item]);
      expect(result.isSuccess, isTrue);

      final deleted = await plugin.cleanupTempFiles();
      expect(deleted, 3);
    });

    test('shareToService overrides targetService accurately', () async {
      final result = await plugin.shareToService(
        ShareTargetService.airDrop,
        ShareParams(
          text: 'AirDrop payload',
          uri: Uri.parse('https://dart.dev'),
        ),
      );

      expect(result.selectedActivityType, 'airDrop');
    });

    test('getCapabilities and canShare return expected values', () async {
      final caps = await plugin.getCapabilities();
      expect(caps.platform, 'macos');
      expect(caps.supportsSystemShareSheet, isTrue);
      expect(caps.supportsAnchorPopover, isTrue);

      final canShare = await plugin.canShare(
        const ShareParams(text: 'Valid payload'),
      );
      expect(canShare, isTrue);
    });
  });
}
