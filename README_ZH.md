# xue_hua_navite_share

**语言 / Language**: [简体中文](README_ZH.md) | [English](README.md)

一款面向生产环境的 Flutter 全平台原生分享插件，完整支持 **Android**、**iOS / iPadOS**、**macOS**、**Windows**、**Linux** 与 **Web** 六大平台。

- **作者**: Matkurban (`3496354336@qq.com`)
- **仓库地址**: [https://github.com/Matkurban/xue_hua_navite_share](https://github.com/Matkurban/xue_hua_navite_share)

## 功能特性对比

| 功能特性 | Android | iOS / iPadOS | macOS | Windows | Linux | Web |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 分享纯文本与主题 (`shareText`) | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |
| 分享链接与富媒体预览头 (`shareUri`) | 支持 | 支持 (`LPLinkMetadata`) | 支持 | 支持 | 支持 | 支持 |
| 分享单文件与多文件 (`shareFiles`) | 支持 (`ContentProvider`) | 支持 | 支持 | 支持 (`CF_HDROP` + 资源管理器) | 支持 (`GtkAppChooserDialog`) | 支持 (`File` API) |
| 分享内存二进制数据 (`shareMemoryFiles`) | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 (`Blob` / `File`) |
| 弹出框锚点定位 (`ShareAnchorRect`) | 无需 | 支持 (`UIPopoverPresentationController`) | 支持 (`NSSharingServicePicker`) | 无需 | 无需 | 无需 |
| 排除特定分享活动/应用 | 支持 (API 24+ `EXTRA_EXCLUDE_COMPONENTS`) | 支持 (`excludedActivityTypes`) | 支持 (`NSSharingServicePickerDelegate`) | 无需 | 无需 | 无需 |
| 定向直达系统服务 (`ShareTargetService`) | 邮件、短信、剪贴板、指定包名 | 邮件、剪贴板 | 隔空投送 (AirDrop)、邮件、信息、阅读列表、Finder、剪贴板 | 邮件、资源管理器定位、剪贴板 | 邮件、文件管理器定位、剪贴板 | 邮件、剪贴板、文件下载降级 |
| 分享结果状态与目标应用回调 (`ShareResult`) | 支持 (`IntentSender` + `ActivityResult`) | 支持 (`completionWithItemsHandler`) | 支持 (`NSSharingServiceDelegate`) | 支持 | 支持 | 支持 (`AbortError` 识别) |
| 运行时平台能力检测 (`getCapabilities`) | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |

## 集成安装

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  xue_hua_navite_share:
    git:
      url: https://github.com/Matkurban/xue_hua_navite_share.git
```

### AI 编程助手 Skills 支持 (`package:skills`)

本插件已严格按照 [Dart Package Skills 官方规范](https://dart.dev/tools/pub/package-skills) 在包根目录内置了标准技能说明文件 [`skills/xue_hua_navite_share-usage/SKILL.md`](skills/xue_hua_navite_share-usage/SKILL.md)。宿主项目可通过以下命令一键安装本插件的 AI 编程指引：

```bash
dart run skills@ get
```

## 各平台差异与集成注意事项

### 1. Android 端注意事项
- **免手动配置 `FileProvider`**：插件内部自带零外部依赖的 `XueHuaShareFileProvider`（Authority 为 `${applicationId}.xue_hua_navite_share.fileprovider`），构建时会自动合并至宿主应用的 `AndroidManifest.xml`，并自动向目标分享应用授予 `FLAG_GRANT_READ_URI_PERMISSION` 临时读取权限。
- **目标应用回调识别**：在 Android 5.1 (API 22)+ 上通过 `Intent.createChooser(intent, title, intentSender)` 配合广播接收器精确捕获用户所选的目标应用 `ComponentName`（格式为 `package/class`）。

### 2. iOS 与 iPadOS 端注意事项
- **富媒体链接与缩略图预览头**：通过 `LinkPresentation` 框架（`LPLinkMetadata`）将 `title`、`uri` 和 `previewThumbnail` 渲染在系统分享面板顶部。
- **iPadOS 弹出框锚点定位（必传建议）**：在 iPadOS 上系统强制以 `UIPopoverPresentationController` 弹出分享面板。请务必传入由触发按钮 `RenderBox` 计算出的 `anchorRect`，否则插件会安全兜底居中显示，但不会指向具体按钮。

### 3. macOS 端注意事项
- **坐标系原点自动转换**：Flutter 采用左上角原点坐标系，而 macOS AppKit `NSView` 默认采用左下角原点坐标系。插件内部自动检测 `view.isFlipped` 并完成 `ShareAnchorRect` 与 `SharePreferredEdge` 的坐标转换。
- **沙盒权限配置 (App Sandbox)**：若宿主应用开启了沙盒，分享用户目录文件或调用邮件服务时，请确保 `macos/Runner/DebugProfile.entitlements` 和 `macos/Runner/Release.entitlements` 中包含必要权限：
  ```xml
  <key>com.apple.security.files.user-selected.read-only</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  ```

### 4. Windows 端注意事项
- 支持将本地文件或内存生成文件写入 Windows 系统剪贴板文件拖拽列表（`CF_HDROP`）及 Unicode 文本剪贴板（`CF_UNICODETEXT`），支持调用 `SHOpenFolderAndSelectItems` 在 Windows 资源管理器中高亮选中文件，并支持通过 `mailto:` 唤起默认邮件客户端。

### 5. Linux 端注意事项
- 采用原生 GTK3 `GtkAppChooserDialog` 弹出应用选择器以使用已安装的桌面程序打开/分享文件；支持通过 D-Bus `org.freedesktop.FileManager1.ShowItems` 在系统文件管理器中定位文件，支持 GIO `mailto:` 邮件拉起与 `GtkClipboard` 剪贴板写入。

### 6. Web 端注意事项
- 基于 W3C **Web Share API Level 2**（`navigator.canShare` 与 `navigator.share`），支持将 `ShareItem.memory` 转换为浏览器原生 `File` 对象进行文件级分享。
- **安全上下文与手势要求**：浏览器要求必须在 `https://`（或 `http://localhost`）安全上下文下，且由用户点击手势（如按钮 `onPressed`）直接触发。当运行在不支持 Web Share API 的桌面浏览器时，若开启 `fallbackToClipboard: true`，插件会自动回退至剪贴板复制或触发浏览器文件下载，并返回 `ShareResultStatus.fallbackExecuted`。

## 完整使用示例

### 1. 分享文本并绑定弹出框锚点

```dart
import 'package:flutter/material.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';

Future<void> shareMessage(BuildContext buttonContext) async {
  final box = buttonContext.findRenderObject() as RenderBox?;
  final anchor = box != null && box.hasSize
      ? ShareAnchorRect.fromRect(box.localToGlobal(Offset.zero) & box.size)
      : null;

  final result = await XueHuaNaviteShare.instance.shareText(
    '欢迎使用 xue_hua_navite_share 全平台原生分享插件！',
    subject: '分享主题',
    title: '分享给好友',
    anchorRect: anchor,
    preferredEdge: SharePreferredEdge.maxY,
  );

  debugPrint('分享状态: ${result.status.wireName}, 目标服务: ${result.selectedActivityType}');
}
```

### 2. 分享带自定义缩略图的链接 (`shareUri`)

```dart
final result = await XueHuaNaviteShare.instance.shareUri(
  Uri.parse('https://github.com/Matkurban/xue_hua_navite_share'),
  title: 'XueHua Native Share 开源仓库',
  subject: 'Flutter 六端原生分享插件',
  message: '支持 Android / iOS / macOS / Windows / Linux / Web 六端原生分享！',
  previewThumbnail: pngBytes,
  anchorRect: anchor,
);
```

### 3. 分享单个或多个本地文件 (`shareFiles`)

```dart
final result = await XueHuaNaviteShare.instance.shareFiles(
  ['/path/to/photo.png', '/path/to/report.pdf'],
  text: '附上项目图片与 PDF 报告',
  subject: '项目归档文件',
  title: '分享文件',
  anchorRect: anchor,
);
```

### 4. 直接分享内存字节数据 (`shareMemoryFiles`) 与清理临时缓存

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
  text: '动态生成的导出文件',
  anchorRect: anchor,
);

// 分享完成后可按需清理原生端为内存分享生成的临时文件
final deletedCount = await XueHuaNaviteShare.instance.cleanupTempFiles();
```

### 5. 定向服务直达分享 (`shareToService`) 与能力检测

```dart
final capabilities = await XueHuaNaviteShare.instance.getCapabilities();
debugPrint('当前平台可用服务: ${capabilities.availableServices}');

final params = ShareParams(
  items: [ShareItem.file('/path/to/archive.zip')],
  targetService: ShareTargetService.airDrop,
);

if (await XueHuaNaviteShare.instance.canShare(params)) {
  final result = await XueHuaNaviteShare.instance.share(params);
}
```

## 开源协议

MIT License. Copyright (c) 2026 Matkurban (`3496354336@qq.com`).
