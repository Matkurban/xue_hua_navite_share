import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/models/share_capabilities.dart';
import 'src/models/share_item.dart';
import 'src/models/share_options.dart';
import 'src/models/share_result.dart';
import 'xue_hua_navite_share_platform_interface.dart';

/// Web implementation of [XueHuaNaviteSharePlatform] backed by the W3C
/// Web Share API Level 2 (`navigator.share` and `navigator.canShare`), with
/// graceful fallbacks to `mailto:`, file download, and the Clipboard API.
class XueHuaNaviteShareWeb extends XueHuaNaviteSharePlatform {
  /// Constructs a [XueHuaNaviteShareWeb].
  XueHuaNaviteShareWeb();

  /// Registers [XueHuaNaviteShareWeb] as the platform implementation on Web.
  static void registerWith(Registrar registrar) {
    XueHuaNaviteSharePlatform.instance = XueHuaNaviteShareWeb();
  }

  bool get _hasNavigatorShare =>
      (web.window.navigator as JSObject).has('share');

  bool get _hasNavigatorCanShare =>
      (web.window.navigator as JSObject).has('canShare');

  @override
  Future<SharePlatformCapabilities> getCapabilities() async {
    final supportsShare = _hasNavigatorShare;
    var supportsFiles = false;
    if (_hasNavigatorCanShare) {
      try {
        final probeBytes = Uint8List.fromList(<int>[116, 101, 115, 116]);
        final probeFile = _createWebFile(probeBytes, 'probe.txt', 'text/plain');
        final shareData = _buildJsShareData(
          files: <web.File>[probeFile],
        );
        supportsFiles = web.window.navigator.canShare(shareData);
      } catch (_) {
        supportsFiles = false;
      }
    }

    return SharePlatformCapabilities(
      platform: 'web',
      supportsSystemShareSheet: supportsShare,
      supportsFileSharing: supportsFiles,
      supportsMultipleFiles: supportsFiles,
      supportsMemoryBytesSharing: true,
      supportsTargetedServices: true,
      supportsAnchorPopover: false,
      supportsExcludedActivities: false,
      supportsChosenTargetCallback: false,
      availableServices: <String>[
        if (supportsShare) 'navigator.share',
        'systemClipboard',
        'mail',
        'downloadFallback',
      ],
    );
  }

  @override
  Future<bool> canShare(ShareParams params) async {
    params.validate();
    if (params.targetService == ShareTargetService.systemClipboard ||
        params.targetService == ShareTargetService.mail) {
      return true;
    }
    if (!_hasNavigatorShare) {
      return params.fallbackToClipboard;
    }
    if (!_hasNavigatorCanShare) {
      return true;
    }
    try {
      final shareData = _buildShareDataFromParams(params);
      return web.window.navigator.canShare(shareData);
    } catch (_) {
      return params.fallbackToClipboard;
    }
  }

  @override
  Future<ShareResult> share(ShareParams params) async {
    params.validate();

    // 1. Direct targeted service: System Clipboard
    if (params.targetService == ShareTargetService.systemClipboard) {
      return _copyToClipboard(params);
    }

    // 2. Direct targeted service: Mail (`mailto:`)
    if (params.targetService == ShareTargetService.mail) {
      return _launchMailto(params);
    }

    // 3. System Web Share API (`navigator.share`)
    if (_hasNavigatorShare) {
      try {
        final shareData = _buildShareDataFromParams(params);
        var canSharePayload = true;
        if (_hasNavigatorCanShare) {
          try {
            canSharePayload = web.window.navigator.canShare(shareData);
          } catch (_) {
            canSharePayload = false;
          }
        }

        if (canSharePayload) {
          await web.window.navigator.share(shareData).toDart;
          return const ShareResult(
            status: ShareResultStatus.success,
            selectedActivityType: 'navigator.share',
            message: 'Shared successfully via Web Share API.',
          );
        }
      } catch (error) {
        final errorStr = error.toString();
        if (errorStr.contains('AbortError') ||
            errorStr.contains('The user aborted a request') ||
            errorStr.contains('cancelled') ||
            errorStr.contains('canceled')) {
          return const ShareResult(
            status: ShareResultStatus.dismissed,
            selectedActivityType: 'navigator.share',
            message: 'User dismissed the Web Share sheet.',
          );
        }
        if (!params.fallbackToClipboard) {
          return ShareResult(
            status: ShareResultStatus.error,
            message: 'Web Share API failed: $errorStr',
          );
        }
      }
    }

    // 4. Fallback: trigger browser download for in-memory files or copy text/URI to clipboard
    final memoryItems = params.resolvedItems
        .where((item) => item.bytes != null && item.bytes!.isNotEmpty)
        .toList();
    if (memoryItems.isNotEmpty) {
      for (final item in memoryItems) {
        _triggerBrowserDownload(
          item.bytes!,
          item.fileName ?? 'shared_file.bin',
          item.mimeType ?? 'application/octet-stream',
        );
      }
      return const ShareResult(
        status: ShareResultStatus.fallbackExecuted,
        selectedActivityType: 'browser.download',
        message:
            'Web Share API for files was unavailable; triggered browser file download fallback.',
      );
    }

    if (params.fallbackToClipboard) {
      return _copyToClipboard(params, isFallback: true);
    }

    return const ShareResult(
      status: ShareResultStatus.unavailable,
      message:
          'Web Share API is unavailable in this browser context (requires HTTPS or localhost).',
    );
  }

  @override
  Future<int> cleanupTempFiles() async {
    // Web operates in-memory with Blob/File objects without persistent temp files.
    return 0;
  }

  web.ShareData _buildShareDataFromParams(ShareParams params) {
    final resolved = params.resolvedItems;
    final webFiles = <web.File>[];
    final textParts = <String>[];
    String? shareUrl = params.uri?.toString();

    for (final item in resolved) {
      if (item.bytes != null && item.bytes!.isNotEmpty) {
        webFiles.add(
          _createWebFile(
            item.bytes!,
            item.fileName ?? 'shared_file',
            item.mimeType ?? 'application/octet-stream',
          ),
        );
      } else if (item.type == ShareItemType.url && item.uri != null) {
        shareUrl ??= item.uri;
        if (item.text != null && item.text!.trim().isNotEmpty) {
          textParts.add(item.text!);
        }
      } else if (item.text != null && item.text!.trim().isNotEmpty) {
        textParts.add(item.text!);
      }
    }

    final combinedText = textParts.isNotEmpty
        ? textParts.join('\n')
        : params.text;

    return _buildJsShareData(
      title: params.title ?? params.subject,
      text: combinedText,
      url: shareUrl,
      files: webFiles.isNotEmpty ? webFiles : null,
    );
  }

  web.ShareData _buildJsShareData({
    String? title,
    String? text,
    String? url,
    List<web.File>? files,
  }) {
    final obj = JSObject();
    if (title != null && title.isNotEmpty) {
      obj.setProperty('title'.toJS, title.toJS);
    }
    if (text != null && text.isNotEmpty) {
      obj.setProperty('text'.toJS, text.toJS);
    }
    if (url != null && url.isNotEmpty) {
      obj.setProperty('url'.toJS, url.toJS);
    }
    if (files != null && files.isNotEmpty) {
      obj.setProperty('files'.toJS, files.toJS);
    }
    return obj as web.ShareData;
  }

  web.File _createWebFile(Uint8List bytes, String fileName, String mimeType) {
    final jsBytes = bytes.toJS;
    final parts = <JSAny>[jsBytes].toJS;
    final options = web.FilePropertyBag(type: mimeType);
    return web.File(parts, fileName, options);
  }

  void _triggerBrowserDownload(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final objectUrl = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = objectUrl;
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(objectUrl);
  }

  Future<ShareResult> _copyToClipboard(
    ShareParams params, {
    bool isFallback = false,
  }) async {
    final parts = <String>[
      if (params.title != null && params.title!.trim().isNotEmpty)
        params.title!,
      if (params.text != null && params.text!.trim().isNotEmpty) params.text!,
      if (params.uri != null) params.uri.toString(),
      for (final item in params.items)
        if (item.text != null && item.text != params.text)
          item.text!
        else if (item.uri != null && item.uri != params.uri?.toString())
          item.uri!,
    ];
    final content = parts.join('\n').trim();
    if (content.isEmpty) {
      return const ShareResult(
        status: ShareResultStatus.unavailable,
        message: 'No text or URL content available to copy to clipboard.',
      );
    }
    await Clipboard.setData(ClipboardData(text: content));
    return ShareResult(
      status: isFallback
          ? ShareResultStatus.fallbackExecuted
          : ShareResultStatus.success,
      selectedActivityType: 'systemClipboard',
      message: isFallback
          ? 'Web Share API unavailable; copied content to clipboard.'
          : 'Copied shared content to clipboard.',
    );
  }

  Future<ShareResult> _launchMailto(ShareParams params) async {
    final recipients = params.emailRecipients.join(',');
    final queryParams = <String, String>{
      if ((params.subject ?? params.title) != null)
        'subject': (params.subject ?? params.title)!,
      if (params.text != null || params.uri != null)
        'body': <String>[
          if (params.text != null) params.text!,
          if (params.uri != null) params.uri.toString(),
        ].join('\n\n'),
      if (params.ccRecipients.isNotEmpty) 'cc': params.ccRecipients.join(','),
      if (params.bccRecipients.isNotEmpty)
        'bcc': params.bccRecipients.join(','),
    };
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: recipients,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    web.window.open(mailtoUri.toString(), '_blank');
    return const ShareResult(
      status: ShareResultStatus.success,
      selectedActivityType: 'mailto',
      message: 'Opened default email client via mailto URI.',
    );
  }
}
