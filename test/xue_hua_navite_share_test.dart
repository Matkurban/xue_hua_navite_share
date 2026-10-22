import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share_platform_interface.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockXueHuaNaviteSharePlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteSharePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final XueHuaNaviteSharePlatform initialPlatform = XueHuaNaviteSharePlatform.instance;

  test('$MethodChannelXueHuaNaviteShare is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteShare>());
  });

  test('getPlatformVersion', () async {
    XueHuaNaviteShare xueHuaNaviteSharePlugin = XueHuaNaviteShare();
    MockXueHuaNaviteSharePlatform fakePlatform = MockXueHuaNaviteSharePlatform();
    XueHuaNaviteSharePlatform.instance = fakePlatform;

    expect(await xueHuaNaviteSharePlugin.getPlatformVersion(), '42');
  });
}
