
import 'xue_hua_navite_share_platform_interface.dart';

class XueHuaNaviteShare {
  Future<String?> getPlatformVersion() {
    return XueHuaNaviteSharePlatform.instance.getPlatformVersion();
  }
}
