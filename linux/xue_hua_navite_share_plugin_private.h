#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_SHARE_PLUGIN_PRIVATE_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_SHARE_PLUGIN_PRIVATE_H_

#include <flutter_linux/flutter_linux.h>

#include "include/xue_hua_navite_share/xue_hua_navite_share_plugin.h"

// Internal helper functions exposed for Linux unit testing.

/// Builds the capabilities FlMethodResponse for Linux.
FlMethodResponse* xue_hua_share_get_capabilities();

/// Validates whether the provided arguments map contains shareable items.
FlMethodResponse* xue_hua_share_can_share(FlValue* args);

/// Cleans up temporary files in `/tmp/xue_hua_share_temp`.
FlMethodResponse* xue_hua_share_cleanup_temp_files();

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_SHARE_PLUGIN_PRIVATE_H_
