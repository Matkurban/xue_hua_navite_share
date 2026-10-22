/// Describes the native sharing features supported by the current host platform.
class SharePlatformCapabilities {
  /// Creates a [SharePlatformCapabilities] instance.
  const SharePlatformCapabilities({
    required this.platform,
    required this.supportsSystemShareSheet,
    required this.supportsFileSharing,
    required this.supportsMultipleFiles,
    required this.supportsMemoryBytesSharing,
    required this.supportsTargetedServices,
    required this.supportsAnchorPopover,
    required this.supportsExcludedActivities,
    required this.supportsChosenTargetCallback,
    this.availableServices = const <String>[],
  });

  /// Reconstructs [SharePlatformCapabilities] from a platform channel map.
  factory SharePlatformCapabilities.fromMap(Map<Object?, Object?> map) {
    final rawServices = map['availableServices'];
    final services = rawServices is List
        ? rawServices.map((e) => e.toString()).toList()
        : const <String>[];
    return SharePlatformCapabilities(
      platform: (map['platform'] as String?) ?? 'unknown',
      supportsSystemShareSheet:
          (map['supportsSystemShareSheet'] as bool?) ?? false,
      supportsFileSharing: (map['supportsFileSharing'] as bool?) ?? false,
      supportsMultipleFiles: (map['supportsMultipleFiles'] as bool?) ?? false,
      supportsMemoryBytesSharing:
          (map['supportsMemoryBytesSharing'] as bool?) ?? false,
      supportsTargetedServices:
          (map['supportsTargetedServices'] as bool?) ?? false,
      supportsAnchorPopover: (map['supportsAnchorPopover'] as bool?) ?? false,
      supportsExcludedActivities:
          (map['supportsExcludedActivities'] as bool?) ?? false,
      supportsChosenTargetCallback:
          (map['supportsChosenTargetCallback'] as bool?) ?? false,
      availableServices: services,
    );
  }

  /// Host platform identifier (`android`, `ios`, `macos`, `windows`, `linux`, `web`).
  final String platform;

  /// Whether the platform provides a native system-wide share sheet or picker.
  final bool supportsSystemShareSheet;

  /// Whether sharing local files is supported.
  final bool supportsFileSharing;

  /// Whether sharing multiple files in a single operation is supported.
  final bool supportsMultipleFiles;

  /// Whether sharing in-memory `Uint8List` buffers is supported.
  final bool supportsMemoryBytesSharing;

  /// Whether directly invoking a specific service (e.g., AirDrop, Mail, Clipboard,
  /// File Explorer) is supported.
  final bool supportsTargetedServices;

  /// Whether popover anchor positioning (`ShareAnchorRect`) is used (iPadOS & macOS).
  final bool supportsAnchorPopover;

  /// Whether excluding specific activity/service types is supported.
  final bool supportsExcludedActivities;

  /// Whether the OS reports the specific target application/service selected by the user.
  final bool supportsChosenTargetCallback;

  /// List of currently available native share service identifiers on the host.
  final List<String> availableServices;

  /// Serializes this capability descriptor into a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'supportsSystemShareSheet': supportsSystemShareSheet,
      'supportsFileSharing': supportsFileSharing,
      'supportsMultipleFiles': supportsMultipleFiles,
      'supportsMemoryBytesSharing': supportsMemoryBytesSharing,
      'supportsTargetedServices': supportsTargetedServices,
      'supportsAnchorPopover': supportsAnchorPopover,
      'supportsExcludedActivities': supportsExcludedActivities,
      'supportsChosenTargetCallback': supportsChosenTargetCallback,
      'availableServices': availableServices,
    };
  }
}
