import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'share_item.dart';

/// Preferred edge for anchoring popover share sheets on macOS (`NSRectEdge`)
/// and iPadOS (`UIPopoverArrowDirection`).
enum SharePreferredEdge {
  /// Left edge (`NSRectEdge.minX` / `UIPopoverArrowDirection.right`).
  minX('minX'),

  /// Top edge (`NSRectEdge.minY` / `UIPopoverArrowDirection.down`).
  minY('minY'),

  /// Right edge (`NSRectEdge.maxX` / `UIPopoverArrowDirection.left`).
  maxX('maxX'),

  /// Bottom edge (`NSRectEdge.maxY` / `UIPopoverArrowDirection.up`).
  maxY('maxY');

  const SharePreferredEdge(this.wireName);

  /// Wire-format identifier sent over the platform channel.
  final String wireName;
}

/// Defines the origin rectangle in Flutter window coordinates (top-left origin)
/// used to anchor popover share pickers on iPadOS and macOS.
class ShareAnchorRect {
  /// Creates a [ShareAnchorRect] from explicit coordinates and dimensions.
  const ShareAnchorRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Creates a [ShareAnchorRect] from a standard Flutter [Rect].
  factory ShareAnchorRect.fromRect(Rect rect) {
    return ShareAnchorRect(
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  /// Horizontal offset from the left edge of the Flutter view.
  final double x;

  /// Vertical offset from the top edge of the Flutter view.
  final double y;

  /// Width of the anchor element.
  final double width;

  /// Height of the anchor element.
  final double height;

  /// Serializes this rectangle into a platform channel map.
  Map<String, double> toMap() {
    return <String, double>{
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

/// System activity types that can be excluded from the share sheet on iOS and macOS.
enum ShareActivityType {
  /// Post to Facebook (`UIActivity.ActivityType.postToFacebook`).
  postToFacebook('postToFacebook'),

  /// Post to X / Twitter (`UIActivity.ActivityType.postToTwitter`).
  postToTwitter('postToTwitter'),

  /// Post to Sina Weibo (`UIActivity.ActivityType.postToWeibo`).
  postToWeibo('postToWeibo'),

  /// System Messages (`UIActivity.ActivityType.message` / `NSSharingService.Name.composeMessage`).
  message('message'),

  /// System Mail (`UIActivity.ActivityType.mail` / `NSSharingService.Name.composeEmail`).
  mail('mail'),

  /// Print activity (`UIActivity.ActivityType.print`).
  print('print'),

  /// Copy to pasteboard (`UIActivity.ActivityType.copyToPasteboard`).
  copyToPasteboard('copyToPasteboard'),

  /// Assign image to a contact (`UIActivity.ActivityType.assignToContact`).
  assignToContact('assignToContact'),

  /// Save image/video to Camera Roll / Photos (`UIActivity.ActivityType.saveToCameraRoll`).
  saveToCameraRoll('saveToCameraRoll'),

  /// Add URL to Safari Reading List (`UIActivity.ActivityType.addToReadingList` / `NSSharingService.Name.addToSafariReadingList`).
  addToReadingList('addToReadingList'),

  /// Post to Flickr (`UIActivity.ActivityType.postToFlickr`).
  postToFlickr('postToFlickr'),

  /// Post to Vimeo (`UIActivity.ActivityType.postToVimeo`).
  postToVimeo('postToVimeo'),

  /// Post to Tencent Weibo (`UIActivity.ActivityType.postToTencentWeibo`).
  postToTencentWeibo('postToTencentWeibo'),

  /// AirDrop (`UIActivity.ActivityType.airDrop` / `NSSharingService.Name.sendViaAirDrop`).
  airDrop('airDrop'),

  /// Open in Apple Books (`UIActivity.ActivityType.openInIBooks`).
  openInIBooks('openInIBooks'),

  /// Markup as PDF (`UIActivity.ActivityType.markupAsPDF`).
  markupAsPDF('markupAsPDF'),

  /// SharePlay activity on iOS 15.4+ (`UIActivity.ActivityType.sharePlay`).
  sharePlay('sharePlay');

  const ShareActivityType(this.wireName);

  /// Wire-format identifier sent over the platform channel.
  final String wireName;
}

/// Target share service to invoke.
///
/// Defaults to [ShareTargetService.systemSheet], which opens the OS native
/// share sheet / picker. Specific targets (such as [airDrop], [mail],
/// [messages], [systemClipboard], or [fileExplorer]) can be invoked directly
/// where supported by the host OS.
enum ShareTargetService {
  /// Default native system share sheet / picker (`UIActivityViewController`,
  /// `NSSharingServicePicker`, Android `Intent.createChooser`, Windows
  /// `DataTransferManager`, Linux `GtkAppChooserDialog`, Web `navigator.share`).
  systemSheet('systemSheet'),

  /// Direct AirDrop sharing (macOS `NSSharingService.Name.sendViaAirDrop`).
  airDrop('airDrop'),

  /// Direct Apple Messages / SMS composer (`NSSharingService.Name.composeMessage` or `sms:`).
  messages('messages'),

  /// Direct Mail / Email client composer (`NSSharingService.Name.composeEmail` or `mailto:`).
  mail('mail'),

  /// Direct Safari Reading List addition (`NSSharingService.Name.addToSafariReadingList`).
  readingList('readingList'),

  /// Copy shared text, URLs, or files directly to the OS system clipboard.
  systemClipboard('systemClipboard'),

  /// Reveal or select shared local files in the native OS file manager
  /// (macOS Finder, Windows Explorer, Linux File Manager).
  fileExplorer('fileExplorer'),

  /// Custom platform service or Android package/component identifier specified
  /// via [ShareParams.customServiceName].
  custom('custom');

  const ShareTargetService(this.wireName);

  /// Wire-format identifier sent over the platform channel.
  final String wireName;
}

/// Encapsulates all items, metadata, UI anchor configuration, exclusions, and
/// service targeting options for a cross-platform share operation.
class ShareParams {
  /// Creates a [ShareParams] configuration.
  ///
  /// At least one item in [items], a non-empty [text], or a [uri] must be provided.
  const ShareParams({
    this.items = const <ShareItem>[],
    this.text,
    this.uri,
    this.subject,
    this.title,
    this.previewThumbnail,
    this.anchorRect,
    this.preferredEdge = SharePreferredEdge.maxY,
    this.excludedActivityTypes = const <ShareActivityType>[],
    this.excludedCustomActivityIdentifiers = const <String>[],
    this.targetService = ShareTargetService.systemSheet,
    this.customServiceName,
    this.emailRecipients = const <String>[],
    this.ccRecipients = const <String>[],
    this.bccRecipients = const <String>[],
    this.fallbackToClipboard = true,
  });

  /// Explicit list of [ShareItem]s (files, memory buffers, URLs, or text blocks).
  final List<ShareItem> items;

  /// Primary text body or caption to share alongside [items] or [uri].
  final String? text;

  /// Primary URI/URL to share.
  final Uri? uri;

  /// Subject line (used by email clients, Android `Intent.EXTRA_SUBJECT`,
  /// iOS `activityViewController(_:subjectForActivityType:)`, macOS Mail service).
  final String? subject;

  /// Share dialog / chooser header title (used by Android `Intent.createChooser`,
  /// iOS `LPLinkMetadata.title`, Windows `DataPackagePropertySet.Title`, Web `ShareData.title`).
  final String? title;

  /// Optional PNG/JPEG thumbnail bytes displayed in the share sheet header preview
  /// (iOS `LPLinkMetadata.imageProvider`, Windows `DataPackagePropertySet.Thumbnail`).
  final Uint8List? previewThumbnail;

  /// Origin rectangle in Flutter window coordinates used to anchor popover share
  /// sheets on iPadOS and macOS.
  final ShareAnchorRect? anchorRect;

  /// Preferred edge for popover placement on macOS and iPadOS.
  final SharePreferredEdge preferredEdge;

  /// System activity types to exclude from the share sheet (iOS and macOS).
  final List<ShareActivityType> excludedActivityTypes;

  /// Platform-specific activity/service identifiers or Android package/component
  /// names (`package/class` or `package`) to exclude from the share sheet.
  final List<String> excludedCustomActivityIdentifiers;

  /// Target share service to invoke (defaults to [ShareTargetService.systemSheet]).
  final ShareTargetService targetService;

  /// Optional custom native service identifier (e.g., macOS `NSSharingService.Name`
  /// raw value or Android target package name) when [targetService] is [ShareTargetService.custom].
  final String? customServiceName;

  /// Optional `To` email addresses when sharing to an email service.
  final List<String> emailRecipients;

  /// Optional `CC` email addresses when sharing to an email service.
  final List<String> ccRecipients;

  /// Optional `BCC` email addresses when sharing to an email service.
  final List<String> bccRecipients;

  /// Whether platforms without an active native share target (such as unsupported
  /// desktop browsers or headless environments) should automatically copy the
  /// shared text/URL to the system clipboard and return `fallbackExecuted`.
  final bool fallbackToClipboard;

  /// Returns the normalized list of all [ShareItem]s derived from [items],
  /// [text], and [uri].
  List<ShareItem> get resolvedItems {
    final list = <ShareItem>[...items];
    if (text != null && text!.trim().isNotEmpty) {
      final alreadyHasSameText = list.any(
        (item) => item.type == ShareItemType.text && item.text == text,
      );
      if (!alreadyHasSameText) {
        list.insert(0, ShareItem.text(text!, subject: subject));
      }
    }
    if (uri != null) {
      final uriString = uri.toString();
      final alreadyHasSameUri = list.any(
        (item) => item.type == ShareItemType.url && item.uri == uriString,
      );
      if (!alreadyHasSameUri) {
        list.add(
          ShareItem.url(
            uri!,
            title: title ?? subject,
            thumbnailBytes: previewThumbnail,
          ),
        );
      }
    }
    return list;
  }

  /// Validates that this [ShareParams] contains at least one shareable payload.
  void validate() {
    if (resolvedItems.isEmpty) {
      throw ArgumentError(
        'ShareParams must contain at least one ShareItem, non-empty text, or a Uri.',
      );
    }
  }

  /// Serializes this [ShareParams] into a map suitable for `StandardMessageCodec`.
  Map<String, Object?> toMap() {
    validate();
    return <String, Object?>{
      'items': resolvedItems.map((e) => e.toMap()).toList(),
      if (text != null) 'text': text,
      if (uri != null) 'uri': uri.toString(),
      if (subject != null) 'subject': subject,
      if (title != null) 'title': title,
      if (previewThumbnail != null) 'previewThumbnail': previewThumbnail,
      if (anchorRect != null) 'anchorRect': anchorRect!.toMap(),
      'preferredEdge': preferredEdge.wireName,
      'excludedActivityTypes': excludedActivityTypes
          .map((e) => e.wireName)
          .toList(),
      'excludedCustomActivityIdentifiers': excludedCustomActivityIdentifiers,
      'targetService': targetService.wireName,
      if (customServiceName != null) 'customServiceName': customServiceName,
      'emailRecipients': emailRecipients,
      'ccRecipients': ccRecipients,
      'bccRecipients': bccRecipients,
      'fallbackToClipboard': fallbackToClipboard,
    };
  }
}
