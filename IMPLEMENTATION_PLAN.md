# `xue_hua_navite_share` 六端完整实现计划书 (Implementation Plan)

- **作者 (Author)**: Matkurban (`3496354336@qq.com`)
- **仓库地址 (Repository)**: [https://github.com/Matkurban/xue_hua_navite_share](https://github.com/Matkurban/xue_hua_navite_share)
- **目标平台 (Target Platforms)**: Android, iOS, macOS, Windows, Linux, Web (共 6 端)

---

## 一、 总体设计目标与架构规划

1. **彻底移除模板冗余代码**：
   - 删除创建插件时默认生成的 `getPlatformVersion()` 方法（涵盖 Dart 层接口、MethodChannel、Web 实现、Android Kotlin、iOS Swift、macOS Swift、Windows C++、Linux C++ 以及所有单元/集成测试与示例项目）。
2. **统一且富有表现力的全功能 Dart API**：
   - 提供单例 `XueHuaNaviteShare.instance` 及构造函数 `const XueHuaNaviteShare()`。
   - 核心方法：
     - `share(ShareParams params)`：支持文本、URL、单文件、多文件、内存二进制数据（`Uint8List`）混合分享，以及标题、主题、缩略图、弹出框锚点、排除项、定向服务等高级配置。
     - `shareText(...)`：快捷分享纯文本与主题。
     - `shareUri(...)`：快捷分享 URI/URL，支持自定义标题、附加消息与富媒体预览缩略图（`previewThumbnail`）。
     - `shareFiles(...)`：快捷分享一个或多个本地文件路径，自动推断 MIME 类型。
     - `shareMemoryFiles(...)`：直接分享内存中的 `Uint8List` 数据块（`ShareItem.memory`），无需调用方手动落盘。
     - `shareToService(...)`：定向调用特定系统级分享服务（如 AirDrop、邮件、信息、Safari 阅读列表、系统剪贴板、文件管理器高亮定位等）。
     - `canShare(ShareParams params)`：运行时检测当前环境是否支持分享指定载荷。
     - `getCapabilities()`：查询当前宿主平台的原生能力矩阵与可用分享服务列表（`SharePlatformCapabilities`）。
     - `cleanupTempFiles()`：清理因分享内存数据（`ShareItem.memory`）而在原生缓存目录生成的临时文件。

---

## 二、 六端平台差异深度研究与原生实现方案

| 平台 | 核心原生 API / 框架 | 关键平台差异与完美解决方案 |
| :--- | :--- | :--- |
| **Android** | `Intent.ACTION_SEND`, `ACTION_SEND_MULTIPLE`, 自定义 `XueHuaShareFileProvider` (`ContentProvider`), `PendingIntent` `IntentSender` | 1. **Android 7.0+ `FileUriExposedException`**：内置零外部依赖的 `XueHuaShareFileProvider`，自动在插件 `AndroidManifest.xml` 中注册 `${applicationId}.xue_hua_navite_share.fileprovider` 并授予 `FLAG_GRANT_READ_URI_PERMISSION`。<br>2. **获知用户所选目标应用**：使用 `Intent.createChooser(intent, title, intentSender)` 配合动态注册的 `BroadcastReceiver` 提取 `Intent.EXTRA_CHOSEN_COMPONENT`。<br>3. **排除特定组件**：在 API 24+ 上支持 `Intent.EXTRA_EXCLUDE_COMPONENTS`。 |
| **iOS / iPadOS** | `UIActivityViewController`, `UIActivityItemSource`, `LinkPresentation` (`LPLinkMetadata`), `UIPopoverPresentationController` | 1. **iPadOS 崩溃防护**：在 iPadOS 上未设置 `popoverPresentationController.sourceView` 与 `sourceRect` 会直接触发原生崩溃。插件支持传入 Flutter 控件坐标 `ShareAnchorRect` 与 `SharePreferredEdge`，并在未传入时自动以当前活跃窗口中心点兜底。<br>2. **富媒体预览头**：自定义 `XueHuaShareActivityItemSource` 实现 `activityViewControllerLinkMetadata(_:)`，支持展示自定义标题、链接与缩略图。 |
| **macOS** | `NSSharingServicePicker`, `NSSharingService`, `NSPasteboard`, `NSWorkspace` | 1. **坐标系原点翻转差异**：Flutter 采用左上角原点，而 AppKit `NSView` 默认采用左下角原点。插件自动检测 `view.isFlipped` 并转换 `y` 轴与 `NSRectEdge`。<br>2. **直达服务与生命周期**：实现 `NSSharingServicePickerDelegate` 与 `NSSharingServiceDelegate`，精准区分用户点击空白处关闭弹窗（`dismissed`）、在子窗口取消（`NSUserCancelledError`）与成功分享（`success`），并支持直达 AirDrop、信息、邮件、阅读列表及 Finder 文件高亮（`activateFileViewerSelecting`）。 |
| **Windows** | Win32 Shell API (`ShellExecuteW`, `SHOpenFolderAndSelectItems`), Windows Clipboard (`CF_HDROP`, `CF_UNICODETEXT`) | 1. **桌面端文件与文本分享体验**：未打包的传统 Win32 桌面应用直接调用 WinRT `ShowShareUIForWindow` 常出现无目标或空白面板。插件结合 `CF_HDROP` 文件拖拽剪贴板写入、`SHOpenFolderAndSelectItems` 资源管理器文件高亮选中、`mailto:` 默认邮件客户端唤起及 Unicode 文本剪贴板，确保任何 Windows 10/11 环境下均能稳定工作。 |
| **Linux** | GTK3 (`GtkAppChooserDialog`, `GtkClipboard`), GIO (`GAppInfo`), D-Bus (`org.freedesktop.FileManager1`) | 1. **桌面环境碎片化**：Linux 缺乏单一的系统级 Share Sheet。针对文件分享，使用原生 GTK 模态对话框 `gtk_app_chooser_dialog_new` 让用户选择系统中支持该 MIME 类型的任意应用打开/发送；针对文件定位，调用 D-Bus `org.freedesktop.FileManager1.ShowItems`；针对邮件与文本，支持 GIO `mailto:` 与 `GtkClipboard`。 |
| **Web** | W3C Web Share API Level 2 (`navigator.share`, `navigator.canShare`), `Blob` / `File`, Clipboard API | 1. **浏览器兼容性与安全限制**：`navigator.share` 仅在 HTTPS / localhost 且部分现代浏览器支持。插件优先通过 `navigator.canShare` 检测并构造原生 JS `File` 数组进行分享；捕获 `AbortError` 识别用户取消（`dismissed`）；在不支持的桌面浏览器自动降级为 `Blob` 文件下载或系统剪贴板复制（返回 `fallbackExecuted`）。 |

---

## 三、 项目元数据、Skills、示例与文档规范清单

1. **项目元数据配置**：
   - `pubspec.yaml`、`ios/xue_hua_navite_share.podspec`、`macos/xue_hua_navite_share.podspec`、`LICENSE` 均已设置为：
     - 作者：`Matkurban`
     - 邮箱：`3496354336@qq.com`
     - 仓库地址：`https://github.com/Matkurban/xue_hua_navite_share`
2. **标准 Package Skills (`https://dart.dev/tools/pub/package-skills`)**：
   - 在插件根目录创建 `skills/xue_hua_navite_share-usage/SKILL.md`，包含符合规范的前缀目录名、YAML frontmatter（`name`、`description`）、核心使用准则（`Guidelines`）、完整代码示例（`Examples`）与避坑指南（`Gotchas`）。
3. **全功能示例项目 (`example/lib/main.dart`)**：
   - 构建交互式工作台 `ShareWorkbenchPage`，涵盖平台能力实时检测、文本分享、带缩略图预览的 URI 分享、内存文件（JSON + PNG）生成与分享、本地多文件分享、定向服务选择、弹出框边缘方向选择、排除打印/AirDrop 开关、临时文件清理及返回结果诊断面板。
4. **中英文双语 README 互链**：
   - `README.md`（英文）与 `README_ZH.md`（简体中文）顶部互相链接，完整演示安装、AI Skills 获取、6 端集成注意事项与全功能代码示例。
