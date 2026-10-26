# xue_hua_navite_share_example

Demonstrates how to use the xue_hua_navite_share plugin.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Linux automated tests

```bash
# Unit + widget
flutter test
cd example && flutter test

# Native integration (avoid running multiple integration_test files in one process on Linux)
flutter test integration_test/plugin_integration_test.dart -d linux
flutter test integration_test/linux_share_smoke_test.dart -d linux
flutter test integration_test/example_ui_linux_test.dart -d linux

# flutter_driver UI + DataHandler coverage (skips GTK AppChooser paths)
flutter drive --driver=test_driver/app_test.dart --target=test_driver/app.dart -d linux
```

Share Memory / Share Local Files via the system sheet open a blocking GTK
`AppChooserDialog` on Linux; automated suites intentionally cover clipboard,
`fileExplorer`, capabilities, `canShare`, and cleanup instead.
