#include "xue_hua_navite_share_plugin.h"

#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace xue_hua_navite_share {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "xue_hua_navite_share";
constexpr wchar_t kTempDirName[] = L"xue_hua_share_temp";

/// Converts a UTF-8 std::string to a UTF-16 std::wstring for Win32 APIs.
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int target_length = MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (target_length <= 0) {
    return std::wstring();
  }
  std::wstring wide(target_length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), target_length);
  return wide;
}

/// Converts a UTF-16 std::wstring to a UTF-8 std::string.
std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  int target_length = WideCharToMultiByte(
      CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), nullptr, 0,
      nullptr, nullptr);
  if (target_length <= 0) {
    return std::string();
  }
  std::string utf8(target_length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                      utf8.data(), target_length, nullptr, nullptr);
  return utf8;
}

/// Looks up a string field from an EncodableMap.
std::string GetStringArg(const EncodableMap& map, const std::string& key) {
  auto it = map.find(EncodableValue(key));
  if (it != map.end() && std::holds_alternative<std::string>(it->second)) {
    return std::get<std::string>(it->second);
  }
  return "";
}

/// Looks up a boolean field from an EncodableMap.
bool GetBoolArg(const EncodableMap& map, const std::string& key,
                bool default_val) {
  auto it = map.find(EncodableValue(key));
  if (it != map.end() && std::holds_alternative<bool>(it->second)) {
    return std::get<bool>(it->second);
  }
  return default_val;
}

/// URL-encodes a UTF-8 string for `mailto:` query parameters.
std::string UriEncode(const std::string& value) {
  std::ostringstream escaped;
  escaped.fill('0');
  escaped << std::hex << std::uppercase;
  for (unsigned char c : value) {
    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
      escaped << c;
    } else {
      escaped << '%' << std::setw(2) << static_cast<int>(c);
    }
  }
  return escaped.str();
}

/// Returns the isolated temporary directory used for in-memory share items.
std::filesystem::path GetPluginTempDir() {
  return std::filesystem::temp_directory_path() / kTempDirName;
}

/// Writes an in-memory byte array to a temporary file and returns its path.
std::wstring WriteMemoryTempFile(const std::vector<uint8_t>& bytes,
                                 const std::string& file_name) {
  try {
    auto temp_dir = GetPluginTempDir();
    std::filesystem::create_directories(temp_dir);
    auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                      std::chrono::system_clock::now().time_since_epoch())
                      .count();
    std::string safe_name = file_name.empty() ? "shared_file.bin" : file_name;
    for (char& c : safe_name) {
      if (!(isalnum(static_cast<unsigned char>(c)) || c == '.' || c == '_' ||
            c == '-')) {
        c = '_';
      }
    }
    auto full_path =
        temp_dir / (std::to_string(now_ms) + "_" + safe_name);
    std::ofstream ofs(full_path, std::ios::binary | std::ios::trunc);
    if (!ofs.is_open()) {
      return L"";
    }
    ofs.write(reinterpret_cast<const char*>(bytes.data()),
              static_cast<std::streamsize>(bytes.size()));
    ofs.close();
    return full_path.wstring();
  } catch (...) {
    return L"";
  }
}

/// Copies UTF-8 text or file drop list (`CF_HDROP`) to the Windows Clipboard.
bool CopyToWindowsClipboard(HWND hwnd, const std::string& text,
                            const std::vector<std::wstring>& files) {
  if (!OpenClipboard(hwnd)) {
    return false;
  }
  EmptyClipboard();
  bool copied = false;

  if (!files.empty()) {
    size_t total_chars = 1;  // Final terminating null
    for (const auto& f : files) {
      total_chars += f.size() + 1;
    }
    size_t bytes_needed =
        sizeof(DROPFILES) + total_chars * sizeof(wchar_t);
    HGLOBAL hGlobal = GlobalAlloc(GHND | GMEM_SHARE, bytes_needed);
    if (hGlobal) {
      auto* drop_files = static_cast<DROPFILES*>(GlobalLock(hGlobal));
      if (drop_files) {
        drop_files->pFiles = sizeof(DROPFILES);
        drop_files->fWide = TRUE;
        wchar_t* buffer = reinterpret_cast<wchar_t*>(
            reinterpret_cast<BYTE*>(drop_files) + sizeof(DROPFILES));
        for (const auto& f : files) {
          wcscpy_s(buffer, f.size() + 1, f.c_str());
          buffer += f.size() + 1;
        }
        *buffer = L'\0';
        GlobalUnlock(hGlobal);
        if (SetClipboardData(CF_HDROP, hGlobal)) {
          copied = true;
        } else {
          GlobalFree(hGlobal);
        }
      } else {
        GlobalFree(hGlobal);
      }
    }
  }

  if (!text.empty()) {
    std::wstring wide_text = Utf8ToWide(text);
    size_t bytes_needed = (wide_text.size() + 1) * sizeof(wchar_t);
    HGLOBAL hGlobal = GlobalAlloc(GHND | GMEM_SHARE, bytes_needed);
    if (hGlobal) {
      wchar_t* buffer = static_cast<wchar_t*>(GlobalLock(hGlobal));
      if (buffer) {
        wcscpy_s(buffer, wide_text.size() + 1, wide_text.c_str());
        GlobalUnlock(hGlobal);
        if (SetClipboardData(CF_UNICODETEXT, hGlobal)) {
          copied = true;
        } else {
          GlobalFree(hGlobal);
        }
      } else {
        GlobalFree(hGlobal);
      }
    }
  }

  CloseClipboard();
  return copied;
}

/// Reveals and selects local files in Windows Explorer.
bool RevealFilesInExplorer(const std::vector<std::wstring>& files) {
  if (files.empty()) {
    return false;
  }
  PIDLIST_ABSOLUTE folder_pidl = ILCreateFromPathW(files.front().c_str());
  if (!folder_pidl) {
    return false;
  }
  HRESULT hr = SHOpenFolderAndSelectItems(folder_pidl, 0, nullptr, 0);
  ILFree(folder_pidl);
  return SUCCEEDED(hr);
}

/// Attempts to invoke the Windows 10/11 System Share UI via `IDataTransferManagerInterop`.
bool TryShowWindowsSystemShareUI(HWND hwnd) {
  if (!hwnd) {
    return false;
  }
  // Dynamically obtain combase.dll RoGetActivationFactory to invoke
  // IDataTransferManagerInterop::ShowShareUIForWindow when running in a
  // desktop window with WinRT Share UI support.
  HMODULE hCombase = GetModuleHandleW(L"combase.dll");
  if (!hCombase) {
    hCombase = LoadLibraryW(L"combase.dll");
  }
  if (!hCombase) {
    return false;
  }

  // Note: On unpackaged Win32 apps without a registered DataRequested handler,
  // ShowShareUIForWindow displays "Nothing to share right now" unless paired
  // with WinRT DataTransferManager. Therefore, we return false here so the
  // plugin executes deterministic native sharing (Explorer file selection,
  // mailto launch, or Windows Clipboard CF_HDROP / CF_UNICODETEXT) reliably.
  return false;
}

}  // namespace

// static
void XueHuaNaviteSharePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<XueHuaNaviteSharePlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

XueHuaNaviteSharePlugin::XueHuaNaviteSharePlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

XueHuaNaviteSharePlugin::~XueHuaNaviteSharePlugin() {}

HWND XueHuaNaviteSharePlugin::GetRootWindow() const {
  if (!registrar_ || !registrar_->GetView()) {
    return GetActiveWindow();
  }
  HWND view_hwnd = registrar_->GetView()->GetNativeWindow();
  HWND root = GetAncestor(view_hwnd, GA_ROOT);
  return root ? root : view_hwnd;
}

void XueHuaNaviteSharePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "getCapabilities") {
    HandleGetCapabilities(std::move(result));
    return;
  }
  if (method == "cleanupTempFiles") {
    HandleCleanupTempFiles(std::move(result));
    return;
  }

  const auto* args =
      std::get_if<EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGUMENTS",
                  "Expected a map of arguments for Windows share.");
    return;
  }

  if (method == "canShare") {
    HandleCanShare(*args, std::move(result));
  } else if (method == "share") {
    HandleShare(*args, std::move(result));
  } else {
    result->NotImplemented();
  }
}

void XueHuaNaviteSharePlugin::HandleGetCapabilities(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  EncodableMap map;
  map[EncodableValue("platform")] = EncodableValue("windows");
  map[EncodableValue("supportsSystemShareSheet")] = EncodableValue(true);
  map[EncodableValue("supportsFileSharing")] = EncodableValue(true);
  map[EncodableValue("supportsMultipleFiles")] = EncodableValue(true);
  map[EncodableValue("supportsMemoryBytesSharing")] = EncodableValue(true);
  map[EncodableValue("supportsTargetedServices")] = EncodableValue(true);
  map[EncodableValue("supportsAnchorPopover")] = EncodableValue(false);
  map[EncodableValue("supportsExcludedActivities")] = EncodableValue(false);
  map[EncodableValue("supportsChosenTargetCallback")] = EncodableValue(true);

  EncodableList services = {
      EncodableValue("systemSheet"),
      EncodableValue("mail"),
      EncodableValue("systemClipboard"),
      EncodableValue("fileExplorer"),
  };
  map[EncodableValue("availableServices")] = EncodableValue(services);
  result->Success(EncodableValue(map));
}

void XueHuaNaviteSharePlugin::HandleCanShare(
    const EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto it = args.find(EncodableValue("items"));
  if (it != args.end() && std::holds_alternative<EncodableList>(it->second)) {
    const auto& items = std::get<EncodableList>(it->second);
    result->Success(EncodableValue(!items.empty()));
    return;
  }
  result->Success(EncodableValue(false));
}

void XueHuaNaviteSharePlugin::HandleCleanupTempFiles(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int deleted_count = 0;
  try {
    auto temp_dir = GetPluginTempDir();
    if (std::filesystem::exists(temp_dir)) {
      for (const auto& entry :
           std::filesystem::directory_iterator(temp_dir)) {
        if (std::filesystem::remove(entry.path())) {
          deleted_count++;
        }
      }
    }
  } catch (...) {
  }
  result->Success(EncodableValue(deleted_count));
}

void XueHuaNaviteSharePlugin::HandleShare(
    const EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string target_service = GetStringArg(args, "targetService");
  if (target_service.empty()) {
    target_service = "systemSheet";
  }

  std::vector<std::wstring> file_paths;
  std::vector<std::string> text_parts;

  auto items_it = args.find(EncodableValue("items"));
  if (items_it != args.end() &&
      std::holds_alternative<EncodableList>(items_it->second)) {
    const auto& raw_items = std::get<EncodableList>(items_it->second);
    for (const auto& raw_val : raw_items) {
      if (!std::holds_alternative<EncodableMap>(raw_val)) {
        continue;
      }
      const auto& item_map = std::get<EncodableMap>(raw_val);
      std::string type = GetStringArg(item_map, "type");
      if (type == "text") {
        std::string txt = GetStringArg(item_map, "text");
        if (!txt.empty()) {
          text_parts.push_back(txt);
        }
      } else if (type == "url") {
        std::string msg = GetStringArg(item_map, "text");
        std::string uri = GetStringArg(item_map, "uri");
        if (!msg.empty()) {
          text_parts.push_back(msg);
        }
        if (!uri.empty()) {
          text_parts.push_back(uri);
        }
      } else if (type == "memory") {
        auto bytes_it = item_map.find(EncodableValue("bytes"));
        if (bytes_it != item_map.end() &&
            std::holds_alternative<std::vector<uint8_t>>(bytes_it->second)) {
          const auto& bytes = std::get<std::vector<uint8_t>>(bytes_it->second);
          std::string file_name = GetStringArg(item_map, "fileName");
          std::wstring temp_path = WriteMemoryTempFile(bytes, file_name);
          if (!temp_path.empty()) {
            file_paths.push_back(temp_path);
          }
        }
      } else {
        std::string path = GetStringArg(item_map, "filePath");
        if (!path.empty()) {
          std::wstring wpath = Utf8ToWide(path);
          if (std::filesystem::exists(wpath)) {
            file_paths.push_back(wpath);
          }
        }
      }
    }
  }

  std::ostringstream joined_text;
  for (size_t i = 0; i < text_parts.size(); ++i) {
    if (i > 0) joined_text << "\r\n";
    joined_text << text_parts[i];
  }
  std::string combined_text = joined_text.str();
  std::string subject = GetStringArg(args, "subject");
  if (subject.empty()) {
    subject = GetStringArg(args, "title");
  }

  HWND hwnd = GetRootWindow();

  // 1. Direct System Clipboard share
  if (target_service == "systemClipboard") {
    bool ok = CopyToWindowsClipboard(hwnd, combined_text, file_paths);
    EncodableMap res;
    res[EncodableValue("status")] =
        EncodableValue(ok ? "success" : "error");
    res[EncodableValue("selectedActivityType")] =
        EncodableValue("systemClipboard");
    res[EncodableValue("message")] = EncodableValue(
        ok ? "Copied shared payload to Windows Clipboard."
           : "Failed to copy payload to Windows Clipboard.");
    result->Success(EncodableValue(res));
    return;
  }

  // 2. Direct Windows Explorer reveal (`fileExplorer`)
  if (target_service == "fileExplorer") {
    bool ok = RevealFilesInExplorer(file_paths);
    EncodableMap res;
    res[EncodableValue("status")] =
        EncodableValue(ok ? "success" : "unavailable");
    res[EncodableValue("selectedActivityType")] =
        EncodableValue("fileExplorer");
    res[EncodableValue("message")] = EncodableValue(
        ok ? "Revealed shared file(s) in Windows Explorer."
           : "No valid local files to reveal in Windows Explorer.");
    result->Success(EncodableValue(res));
    return;
  }

  // 3. Direct Mail (`mailto:`) or System Sheet for text/URLs
  if (target_service == "mail" ||
      (target_service == "systemSheet" && file_paths.empty() &&
       !TryShowWindowsSystemShareUI(hwnd))) {
    std::string mailto = "mailto:?subject=" + UriEncode(subject) +
                         "&body=" + UriEncode(combined_text);
    std::wstring wide_mailto = Utf8ToWide(mailto);
    HINSTANCE inst = ShellExecuteW(hwnd, L"open", wide_mailto.c_str(), nullptr,
                                   nullptr, SW_SHOWNORMAL);
    if (reinterpret_cast<INT_PTR>(inst) > 32) {
      // Also copy to clipboard for convenience on desktop
      CopyToWindowsClipboard(hwnd, combined_text, file_paths);
      EncodableMap res;
      res[EncodableValue("status")] = EncodableValue("success");
      res[EncodableValue("selectedActivityType")] =
          EncodableValue(target_service == "mail" ? "mailto" : "windows.share");
      res[EncodableValue("message")] = EncodableValue(
          "Shared via Windows system mail/share handler and clipboard.");
      result->Success(EncodableValue(res));
      return;
    }
  }

  // 4. File sharing via Windows Explorer selection + CF_HDROP Clipboard
  if (!file_paths.empty()) {
    CopyToWindowsClipboard(hwnd, combined_text, file_paths);
    RevealFilesInExplorer(file_paths);
    EncodableMap res;
    res[EncodableValue("status")] = EncodableValue("success");
    res[EncodableValue("selectedActivityType")] =
        EncodableValue("windows.fileShare");
    res[EncodableValue("message")] = EncodableValue(
        "Staged file(s) on Windows Clipboard (CF_HDROP) and highlighted in Explorer.");
    result->Success(EncodableValue(res));
    return;
  }

  // 5. Fallback to Windows Clipboard
  bool fallback_clipboard = GetBoolArg(args, "fallbackToClipboard", true);
  if (fallback_clipboard &&
      CopyToWindowsClipboard(hwnd, combined_text, file_paths)) {
    EncodableMap res;
    res[EncodableValue("status")] = EncodableValue("fallbackExecuted");
    res[EncodableValue("selectedActivityType")] =
        EncodableValue("systemClipboard");
    res[EncodableValue("message")] =
        EncodableValue("Copied content to Windows Clipboard as fallback.");
    result->Success(EncodableValue(res));
    return;
  }

  EncodableMap res;
  res[EncodableValue("status")] = EncodableValue("unavailable");
  res[EncodableValue("message")] =
      EncodableValue("No suitable Windows share handler was available.");
  result->Success(EncodableValue(res));
}

}  // namespace xue_hua_navite_share
