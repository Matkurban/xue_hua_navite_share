import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models/share_capabilities.dart';
import 'src/models/share_options.dart';
import 'src/models/share_result.dart';
import 'xue_hua_navite_share_platform_interface.dart';

/// An implementation of [XueHuaNaviteSharePlatform] that uses method channels
/// to communicate with Android, iOS, macOS, Windows, and Linux native code.
class MethodChannelXueHuaNaviteShare extends XueHuaNaviteSharePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'xue_hua_navite_share',
  );

  @override
  Future<ShareResult> share(ShareParams params) async {
    params.validate();
    try {
      final response = await methodChannel.invokeMapMethod<Object?, Object?>(
        'share',
        params.toMap(),
      );
      return ShareResult.fromMap(response);
    } on PlatformException catch (error) {
      return ShareResult(
        status: ShareResultStatus.error,
        message: error.message ?? error.code,
        rawData: <String, Object?>{
          'code': error.code,
          if (error.details != null) 'details': error.details,
        },
      );
    }
  }

  @override
  Future<bool> canShare(ShareParams params) async {
    params.validate();
    final result = await methodChannel.invokeMethod<bool>(
      'canShare',
      params.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<SharePlatformCapabilities> getCapabilities() async {
    final map = await methodChannel.invokeMapMethod<Object?, Object?>(
      'getCapabilities',
    );
    if (map == null) {
      return const SharePlatformCapabilities(
        platform: 'unknown',
        supportsSystemShareSheet: false,
        supportsFileSharing: false,
        supportsMultipleFiles: false,
        supportsMemoryBytesSharing: false,
        supportsTargetedServices: false,
        supportsAnchorPopover: false,
        supportsExcludedActivities: false,
        supportsChosenTargetCallback: false,
      );
    }
    return SharePlatformCapabilities.fromMap(map);
  }

  @override
  Future<int> cleanupTempFiles() async {
    final deletedCount = await methodChannel.invokeMethod<int>(
      'cleanupTempFiles',
    );
    return deletedCount ?? 0;
  }
}
