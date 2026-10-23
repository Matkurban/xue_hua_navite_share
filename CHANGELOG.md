## 1.0.1

* Windows: bump googletest to v1.15.2 so builds work with CMake 4.x (Visual Studio).
* Add Windows share smoke integration test (windows_share_smoke_test.dart).

## 1.0.0

* Initial official release of `xue_hua_navite_share` by Matkurban (`3496354336@qq.com`).
* Full 6-platform native sharing support across Android, iOS, macOS, Windows, Linux, and Web:
  * Share plain text, rich subject/title metadata, and URIs/URLs with custom preview thumbnails.
  * Share single and multiple local files (`ShareItem.file`) and in-memory binary streams (`ShareItem.memory`).
  * Support popover anchor positioning (`ShareAnchorRect` and `SharePreferredEdge`) for iPadOS and macOS.
  * Support excluding specific system activities (`ShareActivityType` and custom component/service identifiers).
  * Support direct targeted service sharing (`ShareTargetService`: AirDrop, Mail, Messages, Notes, Reminders, Safari Reading List, System Clipboard, File Manager reveal, etc.).
  * Support accurate completion status and chosen target activity callback (`ShareResult` & `ShareResultStatus`).
  * Support runtime capability discovery (`getCapabilities()`, `canShare()`) and temporary file cache cleanup (`cleanupTempFiles()`).
  * Ship standard Dart package skill under `skills/xue_hua_navite_share-usage/SKILL.md`.

