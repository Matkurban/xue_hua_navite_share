import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelXueHuaNaviteShare platform =
      MethodChannelXueHuaNaviteShare();
  const MethodChannel channel = MethodChannel('xue_hua_navite_share');

  MethodCall? lastCall;

  setUp(() {
    lastCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          lastCall = methodCall;
          switch (methodCall.method) {
            case 'share':
              return <String, Object?>{
                'status': 'success',
                'selectedActivityType': 'com.apple.share.AirDrop.send',
                'message': 'Shared via AirDrop',
              };
            case 'canShare':
              return true;
            case 'getCapabilities':
              return <String, Object?>{
                'platform': 'macos',
                'supportsSystemShareSheet': true,
                'supportsFileSharing': true,
                'supportsMultipleFiles': true,
                'supportsMemoryBytesSharing': true,
                'supportsTargetedServices': true,
                'supportsAnchorPopover': true,
                'supportsExcludedActivities': true,
                'supportsChosenTargetCallback': true,
                'availableServices': <String>['airDrop', 'mail'],
              };
            case 'cleanupTempFiles':
              return 2;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('share invokes method channel and parses ShareResult', () async {
    final result = await platform.share(
      const ShareParams(
        text: 'MethodChannel test payload',
        subject: 'Subject',
      ),
    );

    expect(lastCall?.method, 'share');
    expect(result.status, ShareResultStatus.success);
    expect(result.selectedActivityType, 'com.apple.share.AirDrop.send');
  });

  test('canShare invokes method channel', () async {
    final allowed = await platform.canShare(
      const ShareParams(text: 'Check canShare'),
    );
    expect(lastCall?.method, 'canShare');
    expect(allowed, isTrue);
  });

  test('getCapabilities parses SharePlatformCapabilities', () async {
    final capabilities = await platform.getCapabilities();
    expect(lastCall?.method, 'getCapabilities');
    expect(capabilities.platform, 'macos');
    expect(capabilities.availableServices, contains('airDrop'));
  });

  test('cleanupTempFiles returns deleted file count', () async {
    final count = await platform.cleanupTempFiles();
    expect(lastCall?.method, 'cleanupTempFiles');
    expect(count, 2);
  });
}
