import 'dart:typed_data';

import 'src/models/share_capabilities.dart';
import 'src/models/share_item.dart';
import 'src/models/share_options.dart';
import 'src/models/share_result.dart';
import 'xue_hua_navite_share_platform_interface.dart';

export 'src/models/share_capabilities.dart';
export 'src/models/share_item.dart';
export 'src/models/share_options.dart';
export 'src/models/share_result.dart';
export 'xue_hua_navite_share_platform_interface.dart';

/// Main entry point for the `xue_hua_navite_share` cross-platform native share plugin.
///
/// Supports Android, iOS, macOS, Windows, Linux, and Web with full native feature
/// coverage including text, URLs with link metadata previews, local files,
/// in-memory byte buffers, popover anchor rectangles (for iPadOS & macOS),
/// activity exclusions, direct targeted service sharing, and completion tracking.
class XueHuaNaviteShare {
  /// Constructs a [XueHuaNaviteShare] instance.
  ///
  /// You can also use the shared singleton [XueHuaNaviteShare.instance].
  const XueHuaNaviteShare();

  /// Shared singleton instance of [XueHuaNaviteShare].
  static const XueHuaNaviteShare instance = XueHuaNaviteShare();

  XueHuaNaviteSharePlatform get _platform => XueHuaNaviteSharePlatform.instance;

  /// Shares a customizable [ShareParams] payload across the current platform.
  ///
  /// Returns a [ShareResult] describing whether the user completed the share
  /// ([ShareResultStatus.success]), dismissed the picker ([ShareResultStatus.dismissed]),
  /// triggered a fallback ([ShareResultStatus.fallbackExecuted]), or encountered
  /// an unavailable feature/error.
  Future<ShareResult> share(ShareParams params) {
    return _platform.share(params);
  }

  /// Convenience method to share plain or formatted [text].
  ///
  /// - [subject]: Optional email/message subject line.
  /// - [title]: Optional share sheet header/chooser title.
  /// - [anchorRect]: Optional popover origin rectangle (recommended on iPadOS & macOS).
  /// - [preferredEdge]: Preferred edge for popover placement on macOS & iPadOS.
  /// - [excludedActivityTypes]: System activity types to hide from the share sheet.
  Future<ShareResult> shareText(
    String text, {
    String? subject,
    String? title,
    ShareAnchorRect? anchorRect,
    SharePreferredEdge preferredEdge = SharePreferredEdge.maxY,
    List<ShareActivityType> excludedActivityTypes = const <ShareActivityType>[],
    bool fallbackToClipboard = true,
  }) {
    return share(
      ShareParams(
        items: <ShareItem>[ShareItem.text(text, subject: subject)],
        text: text,
        subject: subject,
        title: title,
        anchorRect: anchorRect,
        preferredEdge: preferredEdge,
        excludedActivityTypes: excludedActivityTypes,
        fallbackToClipboard: fallbackToClipboard,
      ),
    );
  }

  /// Convenience method to share a [Uri] / URL with optional rich preview metadata.
  ///
  /// - [title]: Optional link title shown in the share preview header.
  /// - [message]: Optional accompanying text message shared alongside the URL.
  /// - [subject]: Optional email/message subject line.
  /// - [previewThumbnail]: Optional PNG/JPEG thumbnail bytes for rich previews.
  /// - [anchorRect]: Optional popover origin rectangle (recommended on iPadOS & macOS).
  Future<ShareResult> shareUri(
    Uri uri, {
    String? title,
    String? message,
    String? subject,
    Uint8List? previewThumbnail,
    ShareAnchorRect? anchorRect,
    SharePreferredEdge preferredEdge = SharePreferredEdge.maxY,
    List<ShareActivityType> excludedActivityTypes = const <ShareActivityType>[],
    bool fallbackToClipboard = true,
  }) {
    return share(
      ShareParams(
        items: <ShareItem>[
          ShareItem.url(
            uri,
            title: title ?? subject,
            message: message,
            thumbnailBytes: previewThumbnail,
          ),
        ],
        uri: uri,
        text: message,
        subject: subject,
        title: title,
        previewThumbnail: previewThumbnail,
        anchorRect: anchorRect,
        preferredEdge: preferredEdge,
        excludedActivityTypes: excludedActivityTypes,
        fallbackToClipboard: fallbackToClipboard,
      ),
    );
  }

  /// Convenience method to share one or more local files by their [filePaths].
  ///
  /// - [mimeTypes]: Optional list of explicit MIME types corresponding to [filePaths].
  /// - [text]: Optional accompanying text caption.
  /// - [subject]: Optional subject line.
  /// - [title]: Optional chooser / preview title.
  /// - [anchorRect]: Optional popover origin rectangle (recommended on iPadOS & macOS).
  Future<ShareResult> shareFiles(
    List<String> filePaths, {
    List<String>? mimeTypes,
    String? text,
    String? subject,
    String? title,
    ShareAnchorRect? anchorRect,
    SharePreferredEdge preferredEdge = SharePreferredEdge.maxY,
    List<ShareActivityType> excludedActivityTypes = const <ShareActivityType>[],
  }) {
    if (filePaths.isEmpty) {
      throw ArgumentError.value(
        filePaths,
        'filePaths',
        'At least one file path must be provided.',
      );
    }
    final fileItems = <ShareItem>[
      for (var i = 0; i < filePaths.length; i++)
        ShareItem.file(
          filePaths[i],
          mimeType: (mimeTypes != null && i < mimeTypes.length)
              ? mimeTypes[i]
              : null,
          subject: subject,
        ),
    ];
    return share(
      ShareParams(
        items: fileItems,
        text: text,
        subject: subject,
        title: title,
        anchorRect: anchorRect,
        preferredEdge: preferredEdge,
        excludedActivityTypes: excludedActivityTypes,
      ),
    );
  }

  /// Convenience method to share one or more in-memory binary files ([ShareItem.memory]).
  ///
  /// On native platforms, the plugin writes the bytes to an isolated temporary
  /// directory and cleans them up when [cleanupTempFiles] is invoked. On Web,
  /// browser `File` objects are constructed directly in memory.
  Future<ShareResult> shareMemoryFiles(
    List<ShareItem> memoryItems, {
    String? text,
    String? subject,
    String? title,
    ShareAnchorRect? anchorRect,
    SharePreferredEdge preferredEdge = SharePreferredEdge.maxY,
    List<ShareActivityType> excludedActivityTypes = const <ShareActivityType>[],
  }) {
    if (memoryItems.isEmpty) {
      throw ArgumentError.value(
        memoryItems,
        'memoryItems',
        'At least one memory ShareItem must be provided.',
      );
    }
    return share(
      ShareParams(
        items: memoryItems,
        text: text,
        subject: subject,
        title: title,
        anchorRect: anchorRect,
        preferredEdge: preferredEdge,
        excludedActivityTypes: excludedActivityTypes,
      ),
    );
  }

  /// Directly invokes a specific [ShareTargetService] (such as [ShareTargetService.airDrop],
  /// [ShareTargetService.mail], [ShareTargetService.messages],
  /// [ShareTargetService.systemClipboard], or [ShareTargetService.fileExplorer]).
  Future<ShareResult> shareToService(
    ShareTargetService service,
    ShareParams params,
  ) {
    return share(
      ShareParams(
        items: params.items,
        text: params.text,
        uri: params.uri,
        subject: params.subject,
        title: params.title,
        previewThumbnail: params.previewThumbnail,
        anchorRect: params.anchorRect,
        preferredEdge: params.preferredEdge,
        excludedActivityTypes: params.excludedActivityTypes,
        excludedCustomActivityIdentifiers:
            params.excludedCustomActivityIdentifiers,
        targetService: service,
        customServiceName: params.customServiceName,
        emailRecipients: params.emailRecipients,
        ccRecipients: params.ccRecipients,
        bccRecipients: params.bccRecipients,
        fallbackToClipboard: params.fallbackToClipboard,
      ),
    );
  }

  /// Checks whether the current host platform can share the given [params].
  Future<bool> canShare(ShareParams params) {
    return _platform.canShare(params);
  }

  /// Queries the sharing capabilities and available services on the current platform.
  Future<SharePlatformCapabilities> getCapabilities() {
    return _platform.getCapabilities();
  }

  /// Deletes temporary files created during in-memory or cached share operations.
  ///
  /// Returns the number of deleted temporary files.
  Future<int> cleanupTempFiles() {
    return _platform.cleanupTempFiles();
  }
}
