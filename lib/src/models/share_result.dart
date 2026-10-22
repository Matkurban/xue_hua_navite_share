/// Represents the outcome status of a share operation across all 6 platforms.
enum ShareResultStatus {
  /// The user completed the share action or selected a target application/service.
  success('success'),

  /// The user cancelled or dismissed the share sheet without completing the share.
  dismissed('dismissed'),

  /// The requested share feature or target service is unavailable on the current
  /// device or environment.
  unavailable('unavailable'),

  /// Primary native share UI was unavailable, so a configured fallback action
  /// (such as copying to the system clipboard or launching a `mailto:` link)
  /// was executed instead.
  fallbackExecuted('fallbackExecuted'),

  /// An unexpected platform error occurred during the share operation.
  error('error');

  const ShareResultStatus(this.wireName);

  /// Wire-format identifier sent over the platform channel.
  final String wireName;

  /// Resolves a [ShareResultStatus] from its [wireName].
  static ShareResultStatus fromWireName(String? value) {
    return ShareResultStatus.values.firstWhere(
      (element) => element.wireName == value,
      orElse: () => ShareResultStatus.error,
    );
  }
}

/// Contains the detailed outcome of a share request.
class ShareResult {
  /// Creates a [ShareResult].
  const ShareResult({
    required this.status,
    this.selectedActivityType,
    this.message,
    this.rawData = const <String, Object?>{},
  });

  /// Reconstructs a [ShareResult] from a platform channel response map.
  factory ShareResult.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const ShareResult(
        status: ShareResultStatus.error,
        message: 'Received null response from native share channel.',
      );
    }
    final normalized = <String, Object?>{};
    for (final entry in map.entries) {
      if (entry.key != null) {
        normalized[entry.key.toString()] = entry.value;
      }
    }
    return ShareResult(
      status: ShareResultStatus.fromWireName(normalized['status'] as String?),
      selectedActivityType: normalized['selectedActivityType'] as String?,
      message: normalized['message'] as String?,
      rawData: normalized,
    );
  }

  /// Outcome status of the share operation.
  final ShareResultStatus status;

  /// Identifier of the target service or application chosen by the user, if
  /// reported by the host OS:
  /// - **iOS**: `UIActivity.ActivityType.rawValue` (e.g. `com.apple.UIKit.activity.AirDrop`).
  /// - **macOS**: `NSSharingService.Name.rawValue` (e.g. `com.apple.share.AirDrop.send`).
  /// - **Android**: Flattened `ComponentName` (`package/class`) from `ChooserTarget` callback.
  /// - **Windows / Linux / Web**: Target mechanism identifier (e.g. `DataTransferManager`,
  ///   `navigator.share`, `clipboard`, `mailto`, `fileExplorer`).
  final String? selectedActivityType;

  /// Optional human-readable diagnostic or status message.
  final String? message;

  /// Complete raw platform response dictionary for advanced inspection.
  final Map<String, Object?> rawData;

  /// Returns `true` if the share succeeded natively or via a configured fallback.
  bool get isSuccess =>
      status == ShareResultStatus.success ||
      status == ShareResultStatus.fallbackExecuted;

  /// Returns `true` if the user dismissed or cancelled the share dialog.
  bool get isDismissed => status == ShareResultStatus.dismissed;

  /// Serializes this [ShareResult] into a map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'status': status.wireName,
      if (selectedActivityType != null)
        'selectedActivityType': selectedActivityType,
      if (message != null) 'message': message,
      ...rawData,
    };
  }

  @override
  String toString() {
    return 'ShareResult(status: ${status.wireName}, '
        'selectedActivityType: $selectedActivityType, message: $message)';
  }
}
