import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models/share_capabilities.dart';
import 'src/models/share_options.dart';
import 'src/models/share_result.dart';
import 'xue_hua_navite_share_method_channel.dart';

/// The interface that platform-specific implementations of `xue_hua_navite_share`
/// must extend.
abstract class XueHuaNaviteSharePlatform extends PlatformInterface {
  /// Constructs a [XueHuaNaviteSharePlatform].
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

  /// Executes a native share operation configured with [params].
  Future<ShareResult> share(ShareParams params) {
    throw UnimplementedError('share(params) has not been implemented.');
  }

  /// Checks whether the current platform/environment can share the specified [params].
  Future<bool> canShare(ShareParams params) {
    throw UnimplementedError('canShare(params) has not been implemented.');
  }

  /// Retrieves the sharing capabilities and available services on the current platform.
  Future<SharePlatformCapabilities> getCapabilities() {
    throw UnimplementedError('getCapabilities() has not been implemented.');
  }

  /// Removes temporary files generated during in-memory or cached share operations.
  ///
  /// Returns the number of deleted temporary files.
  Future<int> cleanupTempFiles() {
    throw UnimplementedError('cleanupTempFiles() has not been implemented.');
  }
}
