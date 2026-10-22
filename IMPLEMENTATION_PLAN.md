# `xue_hua_navite_share` 6-Platform Implementation Plan

**Language / 语言**: [English](IMPLEMENTATION_PLAN.md) | [简体中文](IMPLEMENTATION_PLAN_ZH.md)

- **Author**: Matkurban (`3496354336@qq.com`)
-
**Repository**: [https://github.com/Matkurban/xue_hua_navite_share](https://github.com/Matkurban/xue_hua_navite_share)
- **Version**: `1.0.0`
- **Target Platforms**: Android, iOS, macOS, Windows, Linux, Web (All 6 Platforms)
- **Documentation**: [README (English)](README.md) | [README (简体中文)](README_ZH.md)

---

## 1. Overall Design Goals & Architecture

1. **Unified, Expressive Cross-Platform Dart API**:
    - Provides both the `XueHuaNaviteShare.instance` singleton and a `const XueHuaNaviteShare()`
      constructor.
    - Core API surface:
        - `share(ShareParams params)`: Full-featured sharing supporting mixed payloads of plain
          text, URLs, single/multiple local files, and in-memory binary bytes (`Uint8List`), along
          with title, subject, preview thumbnail, popover anchor rectangle, activity exclusions, and
          targeted service routing.
        - `shareText(...)`: Convenience method for sharing plain or formatted text with an optional
          subject line.
        - `shareUri(...)`: Convenience method for sharing a `Uri`/URL with custom header title,
          accompanying message, and rich link preview thumbnail (`previewThumbnail`).
        - `shareFiles(...)`: Convenience method for sharing one or more local file paths with
          automatic MIME type inference.
        - `shareMemoryFiles(...)`: Directly shares in-memory `Uint8List` byte buffers
          (`ShareItem.memory`) without requiring callers to manually write temporary files.
        - `shareToService(...)`: Directly invokes a specific system-level sharing service (such as
          AirDrop, Mail, Messages, Safari Reading List, System Clipboard, or File Explorer/Finder
          reveal).
        - `canShare(ShareParams params)`: Checks at runtime whether the current host platform can
          share the given payload.
        - `getCapabilities()`: Queries the host platform's native capability matrix and available
          sharing services (`SharePlatformCapabilities`).
        - `cleanupTempFiles()`: Cleans up isolated temporary cache files materialized on native
          platforms during in-memory (`ShareItem.memory`) share operations.

---

## 2. Six-Platform Deep Dive & Native Implementation

| Platform         | Core Native APIs / Frameworks                                                                                                      | Key Platform Nuances & Solutions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|:-----------------|:-----------------------------------------------------------------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Android**      | `Intent.ACTION_SEND`, `ACTION_SEND_MULTIPLE`, Custom `XueHuaShareFileProvider` (`ContentProvider`), `PendingIntent` `IntentSender` | 1. **Android 7.0+ `FileUriExposedException` Prevention**: Ships a zero-dependency `XueHuaShareFileProvider` automatically registered in the plugin's `AndroidManifest.xml` under `${applicationId}.xue_hua_navite_share.fileprovider` with automatic `FLAG_GRANT_READ_URI_PERMISSION` grants.<br>2. **Chosen Target App Callback**: Uses `Intent.createChooser(intent, title, intentSender)` paired with a dynamically registered `BroadcastReceiver` to capture `Intent.EXTRA_CHOSEN_COMPONENT`.<br>3. **Component Exclusions**: Supports `Intent.EXTRA_EXCLUDE_COMPONENTS` on Android 7.0 (API 24)+.                                                                                |
| **iOS / iPadOS** | `UIActivityViewController`, `UIActivityItemSource`, `LinkPresentation` (`LPLinkMetadata`), `UIPopoverPresentationController`       | 1. **iPadOS Crash Prevention**: Presenting `UIActivityViewController` on iPadOS without `popoverPresentationController.sourceView` and `sourceRect` triggers an immediate native exception. The plugin accepts Flutter widget bounds via `ShareAnchorRect` and `SharePreferredEdge`, and safely falls back to the center of the active window when omitted.<br>2. **Rich Preview Header**: Custom `XueHuaShareActivityItemSource` implements `activityViewControllerLinkMetadata(_:)` to render custom titles, URLs, and thumbnail images in the share sheet header.                                                                                                                  |
| **macOS**        | `NSSharingServicePicker`, `NSSharingService`, `NSPasteboard`, `NSWorkspace`                                                        | 1. **Coordinate Origin Conversion**: Flutter uses a top-left origin whereas AppKit `NSView` defaults to a bottom-left origin. The plugin automatically checks `view.isFlipped` and converts both the `y` coordinate and `NSRectEdge`.<br>2. **Direct Services & Lifecycle Callbacks**: Implements `NSSharingServicePickerDelegate` and `NSSharingServiceDelegate` to distinguish between dismissing the picker (`dismissed`), cancelling inside a service compose window (`NSUserCancelledError`), and completing a share (`success`). Also supports direct invocation of AirDrop, Messages, Mail, Safari Reading List, and Finder file highlighting (`activateFileViewerSelecting`). |
| **Windows**      | Win32 Shell API (`ShellExecuteW`, `SHOpenFolderAndSelectItems`), Windows Clipboard (`CF_HDROP`, `CF_UNICODETEXT`)                  | 1. **Reliable Desktop File & Text Sharing**: Unpackaged Win32 desktop apps invoking WinRT `ShowShareUIForWindow` frequently encounter empty target lists or handle errors. The plugin combines `CF_HDROP` clipboard file drop staging, `SHOpenFolderAndSelectItems` Windows Explorer file highlighting, `mailto:` default email client launching, and `CF_UNICODETEXT` clipboard writing for rock-solid behavior across Windows 10 and 11.                                                                                                                                                                                                                                            |
| **Linux**        | GTK3 (`GtkAppChooserDialog`, `GtkClipboard`), GIO (`GAppInfo`), D-Bus (`org.freedesktop.FileManager1`)                             | 1. **Desktop Environment Fragmentation**: Linux lacks a single universal share sheet. For file sharing, the plugin presents a native GTK modal `gtk_app_chooser_dialog_new` filtered by MIME type; for file reveal, it invokes D-Bus `org.freedesktop.FileManager1.ShowItems`; for email and text, it supports GIO `mailto:` URI launching and `GtkClipboard`.                                                                                                                                                                                                                                                                                                                        |
| **Web**          | W3C Web Share API Level 2 (`navigator.share`, `navigator.canShare`), `Blob` / `File`, Clipboard API                                | 1. **Browser Compatibility & Security Constraints**: `navigator.share` requires a secure context (`https://` or `localhost`) and user activation. The plugin probes `navigator.canShare` with native JS `File` objects, detects `AbortError` for user cancellation (`dismissed`), and automatically falls back to browser `Blob` downloads or system clipboard copying (`fallbackExecuted`) on unsupported desktop browsers.                                                                                                                                                                                                                                                          |

---

## 3. Package Metadata, Skills, Example App & Documentation Checklist

1. **Unified Version & Metadata (`1.0.0`)**:
    - `pubspec.yaml`, `CHANGELOG.md`, `ios/xue_hua_navite_share.podspec`,
      `macos/xue_hua_navite_share.podspec`, `android/build.gradle.kts`, `windows/CMakeLists.txt`,
      `linux/CMakeLists.txt`, and `example/pubspec.yaml` are all aligned to version `1.0.0`.
    - Author: `Matkurban` (`3496354336@qq.com`)
    - Repository: `https://github.com/Matkurban/xue_hua_navite_share`
2. **Standard Dart Package Skills (`https://dart.dev/tools/pub/package-skills`)**:
    - Ships `skills/xue_hua_navite_share-usage/SKILL.md` with compliant YAML frontmatter (`name`,
      `description`), usage `Guidelines`, complete `Examples`, and platform `Gotchas`.
3. **Interactive Example Workbench (`example/lib/main.dart`)**:
    - Provides `ShareWorkbenchPage` covering real-time capability inspection, text sharing, URI
      sharing with generated PNG preview thumbnails, in-memory file generation & sharing (JSON +
      PNG), local multi-file sharing, direct service routing, popover edge selection, activity
      exclusions, temp cache cleanup, and structured diagnostic logs.
4. **Bilingual Documentation Navigation**:
    - [README.md](README.md) (English) and [README_ZH.md](README_ZH.md) (Simplified Chinese) link to
      each other and
      to [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) / [IMPLEMENTATION_PLAN_ZH.md](IMPLEMENTATION_PLAN_ZH.md).
