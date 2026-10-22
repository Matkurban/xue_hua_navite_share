#include "include/xue_hua_navite_share/xue_hua_navite_share_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <gtk/gtk.h>

#include <cstring>
#include <string>
#include <vector>

#include "xue_hua_navite_share_plugin_private.h"

#define XUE_HUA_NAVITE_SHARE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_navite_share_plugin_get_type(), \
                              XueHuaNaviteSharePlugin))

struct _XueHuaNaviteSharePlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
};

G_DEFINE_TYPE(XueHuaNaviteSharePlugin, xue_hua_navite_share_plugin,
              g_object_get_type())

namespace {

constexpr char kChannelName[] = "xue_hua_navite_share";
constexpr char kTempDirName[] = "xue_hua_share_temp";

/// Looks up a string property inside an `FlValue` map.
const gchar* LookupString(FlValue* map, const char* key) {
  if (!map || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* val = fl_value_lookup_string(map, key);
  if (val && fl_value_get_type(val) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(val);
  }
  return nullptr;
}

/// Looks up a boolean property inside an `FlValue` map.
bool LookupBool(FlValue* map, const char* key, bool default_value) {
  if (!map || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return default_value;
  }
  FlValue* val = fl_value_lookup_string(map, key);
  if (val && fl_value_get_type(val) == FL_VALUE_TYPE_BOOL) {
    return fl_value_get_bool(val);
  }
  return default_value;
}

/// Builds a standard `FlMethodResponse` containing a `ShareResult` map.
FlMethodResponse* MakeShareResultResponse(const char* status,
                                          const char* selected_activity,
                                          const char* message) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "status", fl_value_new_string(status));
  if (selected_activity != nullptr) {
    fl_value_set_string_take(map, "selectedActivityType",
                             fl_value_new_string(selected_activity));
  }
  if (message != nullptr) {
    fl_value_set_string_take(map, "message", fl_value_new_string(message));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

/// Writes an in-memory `Uint8List` buffer to `/tmp/xue_hua_share_temp/`.
std::string WriteTempMemoryFile(const uint8_t* bytes, size_t length,
                                const char* file_name) {
  g_autofree gchar* temp_dir =
      g_build_filename(g_get_tmp_dir(), kTempDirName, nullptr);
  g_mkdir_with_parents(temp_dir, 0700);

  std::string safe_name =
      (file_name && strlen(file_name) > 0) ? file_name : "shared_file.bin";
  for (char& c : safe_name) {
    if (!g_ascii_isalnum(c) && c != '.' && c != '_' && c != '-') {
      c = '_';
    }
  }
  gint64 now_us = g_get_real_time();
  g_autofree gchar* numbered_name =
      g_strdup_printf("%" G_GINT64_FORMAT "_%s", now_us, safe_name.c_str());
  g_autofree gchar* full_path =
      g_build_filename(temp_dir, numbered_name, nullptr);

  g_autoptr(GError) error = nullptr;
  if (!g_file_set_contents(full_path, reinterpret_cast<const gchar*>(bytes),
                           static_cast<gssize>(length), &error)) {
    return "";
  }
  return std::string(full_path);
}

/// Copies text to the primary and default GTK clipboards.
bool CopyToGtkClipboard(const std::string& text) {
  if (text.empty()) {
    return false;
  }
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  if (!clipboard) {
    return false;
  }
  gtk_clipboard_set_text(clipboard, text.c_str(),
                         static_cast<gint>(text.size()));
  gtk_clipboard_store(clipboard);
  return true;
}

/// Reveals local files in the desktop file manager via `org.freedesktop.FileManager1`
/// or `g_app_info_launch_default_for_uri` on the parent directory.
bool RevealInLinuxFileManager(const std::vector<std::string>& file_paths) {
  if (file_paths.empty()) {
    return false;
  }
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) bus =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus != nullptr) {
    GVariantBuilder uri_builder;
    g_variant_builder_init(&uri_builder, G_VARIANT_TYPE("as"));
    for (const auto& path : file_paths) {
      g_autofree gchar* uri = g_filename_to_uri(path.c_str(), nullptr, nullptr);
      if (uri) {
        g_variant_builder_add(&uri_builder, "s", uri);
      }
    }
    g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
        bus, "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
        "org.freedesktop.FileManager1", "ShowItems",
        g_variant_new("(ass)", &uri_builder, ""), nullptr,
        G_DBUS_CALL_FLAGS_NONE, 3000, nullptr, &error);
    if (reply != nullptr) {
      return true;
    }
  }

  // Fallback: open parent directory using GIO default handler
  g_autofree gchar* dir_name = g_path_get_dirname(file_paths.front().c_str());
  g_autofree gchar* dir_uri = g_filename_to_uri(dir_name, nullptr, nullptr);
  if (dir_uri != nullptr) {
    return g_app_info_launch_default_for_uri(dir_uri, nullptr, nullptr);
  }
  return false;
}

}  // namespace

FlMethodResponse* xue_hua_share_get_capabilities() {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "platform", fl_value_new_string("linux"));
  fl_value_set_string_take(map, "supportsSystemShareSheet",
                           fl_value_new_bool(true));
  fl_value_set_string_take(map, "supportsFileSharing", fl_value_new_bool(true));
  fl_value_set_string_take(map, "supportsMultipleFiles",
                           fl_value_new_bool(true));
  fl_value_set_string_take(map, "supportsMemoryBytesSharing",
                           fl_value_new_bool(true));
  fl_value_set_string_take(map, "supportsTargetedServices",
                           fl_value_new_bool(true));
  fl_value_set_string_take(map, "supportsAnchorPopover",
                           fl_value_new_bool(false));
  fl_value_set_string_take(map, "supportsExcludedActivities",
                           fl_value_new_bool(false));
  fl_value_set_string_take(map, "supportsChosenTargetCallback",
                           fl_value_new_bool(true));

  g_autoptr(FlValue) services = fl_value_new_list();
  fl_value_append_take(services, fl_value_new_string("systemSheet"));
  fl_value_append_take(services, fl_value_new_string("mail"));
  fl_value_append_take(services, fl_value_new_string("systemClipboard"));
  fl_value_append_take(services, fl_value_new_string("fileExplorer"));
  fl_value_set_string_take(map, "availableServices",
                           fl_value_ref(services));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

FlMethodResponse* xue_hua_share_can_share(FlValue* args) {
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    g_autoptr(FlValue) res = fl_value_new_bool(false);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(res));
  }
  FlValue* items = fl_value_lookup_string(args, "items");
  bool non_empty = items != nullptr &&
                   fl_value_get_type(items) == FL_VALUE_TYPE_LIST &&
                   fl_value_get_length(items) > 0;
  g_autoptr(FlValue) res = fl_value_new_bool(non_empty);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(res));
}

FlMethodResponse* xue_hua_share_cleanup_temp_files() {
  g_autofree gchar* temp_dir =
      g_build_filename(g_get_tmp_dir(), kTempDirName, nullptr);
  int deleted_count = 0;
  GDir* dir = g_dir_open(temp_dir, 0, nullptr);
  if (dir != nullptr) {
    const gchar* name = nullptr;
    while ((name = g_dir_read_name(dir)) != nullptr) {
      g_autofree gchar* file_path = g_build_filename(temp_dir, name, nullptr);
      if (g_remove(file_path) == 0) {
        deleted_count++;
      }
    }
    g_dir_close(dir);
  }
  g_autoptr(FlValue) res = fl_value_new_int(deleted_count);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(res));
}

static FlMethodResponse* handle_share(XueHuaNaviteSharePlugin* self,
                                      FlValue* args) {
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return MakeShareResultResponse("error", nullptr,
                                   "Invalid arguments passed to Linux share.");
  }

  const gchar* target_service_raw = LookupString(args, "targetService");
  std::string target_service =
      target_service_raw ? target_service_raw : "systemSheet";

  std::vector<std::string> file_paths;
  std::vector<std::string> text_parts;
  std::string primary_mime = "application/octet-stream";

  FlValue* items = fl_value_lookup_string(args, "items");
  if (items && fl_value_get_type(items) == FL_VALUE_TYPE_LIST) {
    size_t len = fl_value_get_length(items);
    for (size_t i = 0; i < len; ++i) {
      FlValue* item = fl_value_get_list_value(items, i);
      if (!item || fl_value_get_type(item) != FL_VALUE_TYPE_MAP) continue;

      const gchar* type_c = LookupString(item, "type");
      std::string type = type_c ? type_c : "file";
      const gchar* mime_c = LookupString(item, "mimeType");
      if (mime_c && strlen(mime_c) > 0) {
        primary_mime = mime_c;
      }

      if (type == "text") {
        const gchar* txt = LookupString(item, "text");
        if (txt && strlen(txt) > 0) {
          text_parts.emplace_back(txt);
        }
      } else if (type == "url") {
        const gchar* msg = LookupString(item, "text");
        const gchar* uri = LookupString(item, "uri");
        if (msg && strlen(msg) > 0) {
          text_parts.emplace_back(msg);
        }
        if (uri && strlen(uri) > 0) {
          text_parts.emplace_back(uri);
        }
      } else if (type == "memory") {
        FlValue* bytes_val = fl_value_lookup_string(item, "bytes");
        if (bytes_val &&
            fl_value_get_type(bytes_val) == FL_VALUE_TYPE_UINT8_LIST) {
          const uint8_t* bytes = fl_value_get_uint8_list(bytes_val);
          size_t byte_len = fl_value_get_length(bytes_val);
          const gchar* file_name = LookupString(item, "fileName");
          std::string temp_path =
              WriteTempMemoryFile(bytes, byte_len, file_name);
          if (!temp_path.empty()) {
            file_paths.push_back(temp_path);
          }
        }
      } else {
        const gchar* path = LookupString(item, "filePath");
        if (path && g_file_test(path, G_FILE_TEST_EXISTS)) {
          file_paths.emplace_back(path);
        }
      }
    }
  }

  std::string combined_text;
  for (size_t i = 0; i < text_parts.size(); ++i) {
    if (i > 0) combined_text += "\n";
    combined_text += text_parts[i];
  }

  // 1. Direct System Clipboard share
  if (target_service == "systemClipboard") {
    std::string clip_payload = combined_text;
    if (clip_payload.empty() && !file_paths.empty()) {
      clip_payload = file_paths.front();
    }
    bool ok = CopyToGtkClipboard(clip_payload);
    return MakeShareResultResponse(
        ok ? "success" : "error", "systemClipboard",
        ok ? "Copied content to Linux GTK clipboard."
           : "Failed to copy content to GTK clipboard.");
  }

  // 2. Direct Linux File Manager reveal (`fileExplorer`)
  if (target_service == "fileExplorer") {
    bool ok = RevealInLinuxFileManager(file_paths);
    return MakeShareResultResponse(
        ok ? "success" : "unavailable", "fileExplorer",
        ok ? "Revealed shared file(s) in Linux file manager."
           : "No valid local files to reveal in Linux file manager.");
  }

  // 3. Direct Mail (`mailto:`) or text/URL share via GIO default URI handler
  const gchar* subject_c = LookupString(args, "subject");
  if (!subject_c) subject_c = LookupString(args, "title");
  std::string subject = subject_c ? subject_c : "";

  if (target_service == "mail" || file_paths.empty()) {
    g_autofree gchar* escaped_subject =
        g_uri_escape_string(subject.c_str(), nullptr, FALSE);
    g_autofree gchar* escaped_body =
        g_uri_escape_string(combined_text.c_str(), nullptr, FALSE);
    g_autofree gchar* mailto_uri = g_strdup_printf(
        "mailto:?subject=%s&body=%s", escaped_subject, escaped_body);

    if (g_app_info_launch_default_for_uri(mailto_uri, nullptr, nullptr)) {
      return MakeShareResultResponse(
          "success", "mailto",
          "Opened Linux default email client via GIO URI launcher.");
    }
  }

  // 4. Native GTK AppChooserDialog for local/memory files
  if (!file_paths.empty()) {
    GtkWindow* parent_window = nullptr;
    if (self->registrar) {
      FlView* view = fl_plugin_registrar_get_view(self->registrar);
      if (view) {
        parent_window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
      }
    }

    g_autoptr(GFile) gfile = g_file_new_for_path(file_paths.front().c_str());
    GtkWidget* dialog = gtk_app_chooser_dialog_new(
        parent_window,
        static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL |
                                    GTK_DIALOG_DESTROY_WITH_PARENT),
        gfile);
    if (!subject.empty()) {
      gtk_app_chooser_dialog_set_heading(GTK_APP_CHOOSER_DIALOG(dialog),
                                         subject.c_str());
    }
    gint response_id = gtk_dialog_run(GTK_DIALOG(dialog));
    if (response_id == GTK_RESPONSE_OK) {
      g_autoptr(GAppInfo) app_info =
          gtk_app_chooser_get_app_info(GTK_APP_CHOOSER(dialog));
      gtk_widget_destroy(dialog);
      if (app_info != nullptr) {
        GList* file_list = nullptr;
        for (const auto& p : file_paths) {
          file_list = g_list_append(file_list, g_file_new_for_path(p.c_str()));
        }
        g_autoptr(GError) launch_err = nullptr;
        bool launched =
            g_app_info_launch(app_info, file_list, nullptr, &launch_err);
        g_list_free_full(file_list, g_object_unref);
        const char* app_id = g_app_info_get_id(app_info);
        return MakeShareResultResponse(
            launched ? "success" : "error",
            app_id ? app_id : "gtk.appChooser",
            launched ? "Shared file(s) with selected Linux application."
                     : (launch_err ? launch_err->message
                                   : "Failed to launch selected application."));
      }
    } else {
      gtk_widget_destroy(dialog);
      return MakeShareResultResponse(
          "dismissed", "gtk.appChooser",
          "User dismissed the Linux GTK application chooser dialog.");
    }
  }

  // 5. Fallback to GTK clipboard
  bool fallback_clipboard = LookupBool(args, "fallbackToClipboard", true);
  if (fallback_clipboard && CopyToGtkClipboard(combined_text)) {
    return MakeShareResultResponse(
        "fallbackExecuted", "systemClipboard",
        "Copied shared content to Linux GTK clipboard as fallback.");
  }

  return MakeShareResultResponse(
      "unavailable", nullptr,
      "No suitable Linux share handler was available.");
}

static void xue_hua_navite_share_plugin_handle_method_call(
    XueHuaNaviteSharePlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "share") == 0) {
    response = handle_share(self, args);
  } else if (strcmp(method, "canShare") == 0) {
    response = xue_hua_share_can_share(args);
  } else if (strcmp(method, "getCapabilities") == 0) {
    response = xue_hua_share_get_capabilities();
  } else if (strcmp(method, "cleanupTempFiles") == 0) {
    response = xue_hua_share_cleanup_temp_files();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_navite_share_plugin_dispose(GObject* object) {
  XueHuaNaviteSharePlugin* self = XUE_HUA_NAVITE_SHARE_PLUGIN(object);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(xue_hua_navite_share_plugin_parent_class)->dispose(object);
}

static void xue_hua_navite_share_plugin_class_init(
    XueHuaNaviteSharePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_navite_share_plugin_dispose;
}

static void xue_hua_navite_share_plugin_init(XueHuaNaviteSharePlugin* self) {
  self->registrar = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  XueHuaNaviteSharePlugin* plugin = XUE_HUA_NAVITE_SHARE_PLUGIN(user_data);
  xue_hua_navite_share_plugin_handle_method_call(plugin, method_call);
}

void xue_hua_navite_share_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  XueHuaNaviteSharePlugin* plugin = XUE_HUA_NAVITE_SHARE_PLUGIN(
      g_object_new(xue_hua_navite_share_plugin_get_type(), nullptr));
  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
