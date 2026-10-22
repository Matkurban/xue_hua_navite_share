#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_SHARE_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_SHARE_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>

namespace xue_hua_navite_share {

/// Windows implementation of the `xue_hua_navite_share` plugin.
///
/// Supports:
/// - Windows 10/11 Native Share UI (`IDataTransferManagerInterop` / `DataTransferManager`)
///   with automatic fallback to Explorer / mailto / Clipboard when WinRT share targets
///   are unavailable.
/// - Direct file selection in Windows Explorer (`SHOpenFolderAndSelectItems`).
/// - Direct system clipboard sharing (`CF_UNICODETEXT` and `CF_HDROP` for file drops).
/// - Direct email composition via `mailto:` (`ShellExecuteW`).
/// - Temporary file materialization and cleanup for `ShareItem.memory`.
class XueHuaNaviteSharePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit XueHuaNaviteSharePlugin(
      flutter::PluginRegistrarWindows* registrar = nullptr);

  virtual ~XueHuaNaviteSharePlugin();

  // Disallow copy and assign.
  XueHuaNaviteSharePlugin(const XueHuaNaviteSharePlugin&) = delete;
  XueHuaNaviteSharePlugin& operator=(const XueHuaNaviteSharePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  flutter::PluginRegistrarWindows* registrar_;

  HWND GetRootWindow() const;
  void HandleShare(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleCanShare(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetCapabilities(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleCleanupTempFiles(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace xue_hua_navite_share

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_SHARE_PLUGIN_H_
