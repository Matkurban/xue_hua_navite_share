import 'dart:typed_data';

/// Enumerates the kind of payload represented by a [ShareItem].
enum ShareItemType {
  /// Plain or formatted text content (`text/plain`, `text/html`, etc.).
  text('text'),

  /// A web URL or custom URI scheme (`https://`, `mailto:`, `file://`, etc.).
  url('url'),

  /// A file stored on the local filesystem, referenced by [ShareItem.filePath].
  file('file'),

  /// An image file or in-memory image buffer (`image/*`).
  image('image'),

  /// A video file or in-memory video buffer (`video/*`).
  video('video'),

  /// An audio file or in-memory audio buffer (`audio/*`).
  audio('audio'),

  /// Raw binary bytes stored in memory ([ShareItem.bytes]).
  memory('memory');

  const ShareItemType(this.wireName);

  /// Wire-format identifier sent over the platform channel.
  final String wireName;

  /// Resolves a [ShareItemType] from its [wireName], defaulting to [ShareItemType.file].
  static ShareItemType fromWireName(String? value) {
    return ShareItemType.values.firstWhere(
      (element) => element.wireName == value,
      orElse: () => ShareItemType.file,
    );
  }
}

/// Represents a single shareable item (text, URL, local file, or in-memory bytes).
///
/// Multiple [ShareItem] instances can be combined inside a single `ShareParams`
/// request to share mixed payloads (such as multiple images with a caption and
/// a link) across Android, iOS, macOS, Windows, Linux, and Web.
class ShareItem {
  /// Creates a generic [ShareItem].
  ///
  /// Prefer using the named factory constructors ([ShareItem.text],
  /// [ShareItem.url], [ShareItem.file], [ShareItem.memory]) for clarity.
  const ShareItem({
    required this.type,
    this.text,
    this.uri,
    this.filePath,
    this.fileName,
    this.mimeType,
    this.subject,
    this.bytes,
    this.thumbnailBytes,
  });

  /// Creates a text share item.
  ///
  /// - [text]: The body text to share.
  /// - [subject]: Optional subject or title associated with this text item.
  /// - [mimeType]: Optional MIME type (defaults to `text/plain`).
  factory ShareItem.text(
    String text, {
    String? subject,
    String? mimeType = 'text/plain',
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Shared text cannot be empty.');
    }
    return ShareItem(
      type: ShareItemType.text,
      text: text,
      subject: subject,
      mimeType: mimeType,
    );
  }

  /// Creates a URL/URI share item.
  ///
  /// - [uri]: The target [Uri] to share.
  /// - [title]: Optional link title displayed in rich share previews (e.g., iOS `LPLinkMetadata`).
  /// - [message]: Optional accompanying explanatory text.
  /// - [thumbnailBytes]: Optional PNG/JPEG thumbnail bytes for rich link previews.
  factory ShareItem.url(
    Uri uri, {
    String? title,
    String? message,
    Uint8List? thumbnailBytes,
  }) {
    return ShareItem(
      type: ShareItemType.url,
      uri: uri.toString(),
      subject: title,
      text: message,
      mimeType: 'text/uri-list',
      thumbnailBytes: thumbnailBytes,
    );
  }

  /// Creates a local file share item.
  ///
  /// - [filePath]: Absolute path to the file on the device filesystem.
  /// - [fileName]: Optional display filename override. If omitted, inferred from [filePath].
  /// - [mimeType]: Optional explicit MIME type (e.g., `image/png`, `application/pdf`).
  ///   If omitted, inferred automatically from the file extension.
  /// - [thumbnailBytes]: Optional preview thumbnail bytes.
  factory ShareItem.file(
    String filePath, {
    String? fileName,
    String? mimeType,
    String? subject,
    Uint8List? thumbnailBytes,
  }) {
    if (filePath.trim().isEmpty) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'File path cannot be empty.',
      );
    }
    final resolvedName = fileName ?? _extractFileName(filePath);
    final resolvedMime = mimeType ?? inferMimeType(resolvedName);
    final resolvedType = _inferItemTypeFromMime(
      resolvedMime,
      fallback: ShareItemType.file,
    );
    return ShareItem(
      type: resolvedType,
      filePath: filePath,
      fileName: resolvedName,
      mimeType: resolvedMime,
      subject: subject,
      thumbnailBytes: thumbnailBytes,
    );
  }

  /// Creates an in-memory binary share item without requiring the caller to
  /// manually write a temporary file first.
  ///
  /// On native platforms, the plugin automatically materializes [bytes] into an
  /// isolated temporary cache file (and cleans it up via `cleanupTempFiles()`),
  /// while on Web it directly constructs a browser `File` object in memory.
  ///
  /// - [bytes]: Raw file bytes.
  /// - [fileName]: Required file name including extension (e.g., `poster.png`).
  /// - [mimeType]: Optional MIME type. If omitted, inferred from [fileName].
  /// - [thumbnailBytes]: Optional preview thumbnail bytes.
  factory ShareItem.memory({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subject,
    Uint8List? thumbnailBytes,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Memory share bytes cannot be empty.',
      );
    }
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'File name cannot be empty for memory share items.',
      );
    }
    final resolvedMime = mimeType ?? inferMimeType(fileName);
    return ShareItem(
      type: ShareItemType.memory,
      bytes: bytes,
      fileName: fileName,
      mimeType: resolvedMime,
      subject: subject,
      thumbnailBytes: thumbnailBytes,
    );
  }

  /// Reconstructs a [ShareItem] from a platform channel map.
  factory ShareItem.fromMap(Map<Object?, Object?> map) {
    return ShareItem(
      type: ShareItemType.fromWireName(map['type'] as String?),
      text: map['text'] as String?,
      uri: map['uri'] as String?,
      filePath: map['filePath'] as String?,
      fileName: map['fileName'] as String?,
      mimeType: map['mimeType'] as String?,
      subject: map['subject'] as String?,
      bytes: map['bytes'] as Uint8List?,
      thumbnailBytes: map['thumbnailBytes'] as Uint8List?,
    );
  }

  /// The category of this share item.
  final ShareItemType type;

  /// Text content or accompanying message.
  final String? text;

  /// URI/URL string when sharing a link.
  final String? uri;

  /// Absolute local filesystem path when sharing a file on disk.
  final String? filePath;

  /// File name with extension (e.g., `report.pdf`).
  final String? fileName;

  /// Explicit or inferred MIME type (e.g., `image/png`, `application/pdf`).
  final String? mimeType;

  /// Item-specific subject or title metadata.
  final String? subject;

  /// In-memory payload bytes when [type] is [ShareItemType.memory].
  final Uint8List? bytes;

  /// Optional PNG/JPEG thumbnail bytes for rich share previews.
  final Uint8List? thumbnailBytes;

  /// Serializes this [ShareItem] into a map suitable for `StandardMessageCodec`.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'type': type.wireName,
      if (text != null) 'text': text,
      if (uri != null) 'uri': uri,
      if (filePath != null) 'filePath': filePath,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (subject != null) 'subject': subject,
      if (bytes != null) 'bytes': bytes,
      if (thumbnailBytes != null) 'thumbnailBytes': thumbnailBytes,
    };
  }

  /// Infers a standard MIME type from a file path or filename.
  static String inferMimeType(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    final dotIndex = lower.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == lower.length - 1) {
      return 'application/octet-stream';
    }
    final ext = lower.substring(dotIndex + 1);
    return _extensionToMime[ext] ?? 'application/octet-stream';
  }

  static String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : 'shared_file';
  }

  static ShareItemType _inferItemTypeFromMime(
    String mimeType, {
    required ShareItemType fallback,
  }) {
    if (mimeType.startsWith('image/')) return ShareItemType.image;
    if (mimeType.startsWith('video/')) return ShareItemType.video;
    if (mimeType.startsWith('audio/')) return ShareItemType.audio;
    return fallback;
  }

  static const Map<String, String> _extensionToMime = <String, String>{
    'txt': 'text/plain',
    'md': 'text/markdown',
    'html': 'text/html',
    'htm': 'text/html',
    'csv': 'text/csv',
    'json': 'application/json',
    'xml': 'application/xml',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    '7z': 'application/x-7z-compressed',
    'rar': 'application/vnd.rar',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'bmp': 'image/bmp',
    'ico': 'image/x-icon',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'vcf': 'text/vcard',
    'ics': 'text/calendar',
    'apk': 'application/vnd.android.package-archive',
  };
}
