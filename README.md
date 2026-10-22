# xue_hua_navite_share

**Language / 语言**: [English](README.md) | [简体中文](README_ZH.md)  
**Architecture & Implementation Plan**: [Implementation Plan (English)](IMPLEMENTATION_PLAN.md)

A production-ready, cross-platform native share Flutter plugin supporting **Android**, **iOS / iPadOS**, **macOS**, **Windows**, **Linux**, and **Web**.

- **Author**: Matkurban (`3496354336@qq.com`)
- **Version**: `1.0.0`
- **Repository**: [https://github.com/Matkurban/xue_hua_navite_share](https://github.com/Matkurban/xue_hua_navite_share)

## Features

| Capability                                         |                 Android                  |              iOS / iPadOS               |                          macOS                           |           Windows           |             Linux             |             Web              |
|:---------------------------------------------------|:----------------------------------------:|:---------------------------------------:|:--------------------------------------------------------:|:---------------------------:|:-----------------------------:|:----------------------------:|
| Share Plain / Formatted Text (`shareText`)         |                   Yes                    |                   Yes                   |                           Yes                            |             Yes             |              Yes              |             Yes              |
| Share URI / URL + Rich Preview (`shareUri`)        |                   Yes                    |         Yes (`LPLinkMetadata`)          |                           Yes                            |             Yes             |              Yes              |             Yes              |
| Share Single & Multiple Local Files (`shareFiles`) |         Yes (`ContentProvider`)          |                   Yes                   |                           Yes                            | Yes (`CF_HDROP` + Explorer) |  Yes (`GtkAppChooserDialog`)  |       Yes (`File` API)       |
| Share In-Memory Bytes (`shareMemoryFiles`)         |                   Yes                    |                   Yes                   |                           Yes                            |             Yes             |              Yes              |    Yes (`Blob` / `File`)     |
| Popover Anchor Positioning (`ShareAnchorRect`)     |                   N/A                    | Yes (`UIPopoverPresentationController`) |              Yes (`NSSharingServicePicker`)              |             N/A             |              N/A              |             N/A              |
| Activity / Service Exclusions                      | Yes (API 24+ `EXTRA_EXCLUDE_COMPONENTS`) |      Yes (`excludedActivityTypes`)      |          Yes (`NSSharingServicePickerDelegate`)          |             N/A             |              N/A              |             N/A              |
| Direct Targeted Service (`ShareTargetService`)     |   Mail, SMS, Clipboard, Custom Package   |             Mail, Clipboard             | AirDrop, Mail, Messages, Reading List, Finder, Clipboard |  Mail, Explorer, Clipboard  | Mail, File Manager, Clipboard |  Mail, Clipboard, Download   |
| Completion Status & Chosen Target Callback         | Yes (`IntentSender` + `ActivityResult`)  |   Yes (`completionWithItemsHandler`)    |             Yes (`NSSharingServiceDelegate`)             |             Yes             |              Yes              | Yes (`AbortError` detection) |
| Runtime Capability Inspection (`getCapabilities`)  |                   Yes                    |                   Yes                   |                           Yes                            |             Yes             |              Yes              |             Yes              |

## Installation

Add `xue_hua_navite_share` from [pub.dev](https://pub.dev/packages/xue_hua_navite_share) to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_navite_share: ^1.0.0
```

Or install via the Flutter CLI:

```bash
flutter pub add xue_hua_navite_share
```

### AI Coding Agent Skills (`package:skills`)

This package ships with an official AI Agent Skill under [`skills/xue_hua_navite_share-usage/SKILL.md`](skills/xue_hua_navite_share-usage/SKILL.md) following the [Dart Package Skills specification](https://dart.dev/tools/pub/package-skills). Consumers can install the bundled skill into their project using:

```bash
dart run skills@ get
```

## Platform Integration & Notes

For full architectural details and native implementation design across all 6 platforms, see the [Implementation Plan](IMPLEMENTATION_PLAN.md).

### 1. Android
- **Zero Manual `FileProvider` Setup**: The plugin automatically registers its own self-contained `XueHuaShareFileProvider` (`${applicationId}.xue_hua_navite_share.fileprovider`) in its `AndroidManifest.xml` and grants temporary `FLAG_GRANT_READ_URI_PERMISSION` to resolved target apps.
- **Target Callback**: Uses `Intent.createChooser(intent, title, intentSender)` with an internal `BroadcastReceiver` to capture the exact `ComponentName` (`package/class`) selected by the user.

### 2. iOS & iPadOS
- **Rich Link & Image Previews**: Uses `LinkPresentation` (`LPLinkMetadata`) to display custom `title`, `uri`, and `previewThumbnail` in the iOS Share Sheet header.
- **iPadOS Popover Requirement**: On iPadOS, `UIActivityViewController` is presented inside a `UIPopoverPresentationController`. Always pass `anchorRect` (computed from the tapped button's `RenderBox`) so the popover points to the triggering button rather than falling back to the center of the screen.

### 3. macOS
- **Coordinate System Conversion**: Flutter uses a top-left coordinate origin, whereas AppKit `NSView` uses a bottom-left origin by default. `XueHuaNaviteSharePlugin` automatically inspects `view.isFlipped` and converts `ShareAnchorRect` and `SharePreferredEdge` before calling `NSSharingServicePicker.show(relativeTo:of:preferredEdge:)`.
- **App Sandbox Entitlements**: If your macOS app is sandboxed and shares user-selected files or composes emails, ensure `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` include:
  ```xml
  <key>com.apple.security.files.user-selected.read-only</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  ```

### 4. Windows
- Supports native file staging on the Windows Clipboard (`CF_HDROP`), Unicode text (`CF_UNICODETEXT`), revealing and selecting shared files in Windows Explorer (`SHOpenFolderAndSelectItems`), and launching email clients via `mailto:` (`ShellExecuteW`).

### 5. Linux
- Uses `GtkAppChooserDialog` for selecting installed desktop applications to handle shared files, `org.freedesktop.FileManager1.ShowItems` (via D-Bus) to reveal files in the system file manager, GIO default URI launching for `mailto:`, and `GtkClipboard` for clipboard operations.

### 6. Web
- Implements W3C **Web Share API Level 2** (`navigator.canShare` and `navigator.share`) supporting both text/URLs and binary `File` objects constructed from `ShareItem.memory`.
- **Important**: Browsers require `https://` (or `http://localhost`) and a transient user activation gesture (such as a button `onPressed`) to invoke `navigator.share`. When unsupported, the plugin automatically executes a clipboard copy or browser file download fallback (`ShareResultStatus.fallbackExecuted`).

## Usage Examples

### 1. Share Text with Popover Anchor

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

Future<void> shareMessage(BuildContext buttonContext) async {
  final box = buttonContext.findRenderObject() as RenderBox?;
  final anchor = box != null && box.hasSize
      ? ShareAnchorRect.fromRect(box.localToGlobal(Offset.zero) & box.size)
      : null;

  final result = await XueHuaNaviteShare.instance.shareText(
    'Hello from xue_hua_navite_share!',
    subject: 'Greeting Subject',
    title: 'Share Greeting',
    anchorRect: anchor,
    preferredEdge: SharePreferredEdge.maxY,
  );

  debugPrint('Status: ${result.status.wireName}, Target: ${result.selectedActivityType}');
}
```

### 2. Share URL with Custom Preview Thumbnail

```dart
final result = await XueHuaNaviteShare.instance.shareUri(
  Uri.parse('https://github.com/Matkurban/xue_hua_navite_share'),
  title: 'XueHua Native Share Repository',
  subject: '6-Platform Flutter Native Share Plugin',
  message: 'Explore the 6-platform native share plugin on GitHub!',
  previewThumbnail: pngBytes,
  anchorRect: anchor,
);
```

### 3. Share Single or Multiple Local Files

```dart
final result = await XueHuaNaviteShare.instance.shareFiles(
  ['/path/to/photo.png', '/path/to/report.pdf'],
  text: 'Attached project deliverables',
  subject: 'Project Deliverables',
  title: 'Share Files',
  anchorRect: anchor,
);
```

### 4. Share In-Memory Binary Files (`Uint8List`) & Clean Up Cache

```dart
final result = await XueHuaNaviteShare.instance.shareMemoryFiles(
  [
    ShareItem.memory(
      bytes: jsonBytes,
      fileName: 'config.json',
      mimeType: 'application/json',
    ),
    ShareItem.memory(
      bytes: pngBytes,
      fileName: 'poster.png',
      mimeType: 'image/png',
    ),
  ],
  text: 'Generated report files',
  anchorRect: anchor,
);

// Remove temporary files materialized for native share sheets
final deletedCount = await XueHuaNaviteShare.instance.cleanupTempFiles();
```

### 5. Direct Targeted Service Sharing & Capability Discovery

```dart
final capabilities = await XueHuaNaviteShare.instance.getCapabilities();
debugPrint('Available services: ${capabilities.availableServices}');

final params = ShareParams(
  items: [ShareItem.file('/path/to/archive.zip')],
  targetService: ShareTargetService.airDrop,
);

if (await XueHuaNaviteShare.instance.canShare(params)) {
  final result = await XueHuaNaviteShare.instance.share(params);
}
```

## License

See the [LICENSE](LICENSE) file for details.
