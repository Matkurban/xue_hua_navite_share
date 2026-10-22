import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'xue_hua_navite_share_method_channel.dart';

abstract class XueHuaNaviteSharePlatform extends PlatformInterface {
  /// Constructs a XueHuaNaviteSharePlatform.
  XueHuaNaviteSharePlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteSharePlatform _instance = MethodChannelXueHuaNaviteShare();

  /// The default instance of [XueHuaNaviteSharePlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteShare].
  static XueHuaNaviteSharePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteSharePlatform] when
  /// they register themselves.
  static set instance(XueHuaNaviteSharePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
