import Flutter
import LinkPresentation
import UIKit

/// Custom `UIActivityItemSource` that provides rich `LPLinkMetadata` (title, URL,
/// and preview thumbnail image) and subject metadata to `UIActivityViewController`.
final class XueHuaShareActivityItemSource: NSObject, UIActivityItemSource {
  private let item: Any
  private let subject: String?
  private let title: String?
  private let previewImage: UIImage?
  private let url: URL?

  init(
    item: Any,
    subject: String? = nil,
    title: String? = nil,
    previewImage: UIImage? = nil,
    url: URL? = nil
  ) {
    self.item = item
    self.subject = subject
    self.title = title
    self.previewImage = previewImage
    self.url = url
    super.init()
  }

  func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    return item
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    return item
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    return subject ?? title ?? ""
  }

  func activityViewControllerLinkMetadata(
    _ activityViewController: UIActivityViewController
  ) -> LPLinkMetadata? {
    guard title != nil || subject != nil || previewImage != nil || url != nil else {
      return nil
    }
    let metadata = LPLinkMetadata()
    if let headerTitle = title ?? subject, !headerTitle.isEmpty {
      metadata.title = headerTitle
    }
    if let targetUrl = url ?? (item as? URL) {
      metadata.originalURL = targetUrl
      metadata.url = targetUrl
    }
    if let image = previewImage {
      let provider = NSItemProvider(object: image)
      metadata.imageProvider = provider
      metadata.iconProvider = provider
    }
    return metadata
  }
}

/// iOS implementation of `xue_hua_navite_share` supporting `UIActivityViewController`,
/// `LPLinkMetadata` previews, iPadOS `UIPopoverPresentationController` anchor positioning,
/// activity exclusions, in-memory binary files, and targeted services.
public class XueHuaNaviteSharePlugin: NSObject, FlutterPlugin {
  private static let channelName = "xue_hua_navite_share"
  private static let tempDirName = "xue_hua_share_temp"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = XueHuaNaviteSharePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "share":
      handleShare(call, result: result)
    case "canShare":
      handleCanShare(call, result: result)
    case "getCapabilities":
      handleGetCapabilities(result: result)
    case "cleanupTempFiles":
      handleCleanupTempFiles(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleGetCapabilities(result: @escaping FlutterResult) {
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    result([
      "platform": "ios",
      "supportsSystemShareSheet": true,
      "supportsFileSharing": true,
      "supportsMultipleFiles": true,
      "supportsMemoryBytesSharing": true,
      "supportsTargetedServices": true,
      "supportsAnchorPopover": isPad,
      "supportsExcludedActivities": true,
      "supportsChosenTargetCallback": true,
      "availableServices": [
        "systemSheet",
        "airDrop",
        "messages",
        "mail",
        "readingList",
        "systemClipboard",
      ],
    ])
  }

  private func handleCanShare(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let items = args["items"] as? [[String: Any]],
          !items.isEmpty
    else {
      result(false)
      return
    }
    result(true)
  }

  private func handleCleanupTempFiles(result: @escaping FlutterResult) {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      Self.tempDirName,
      isDirectory: true
    )
    guard FileManager.default.fileExists(atPath: tempDir.path) else {
      result(0)
      return
    }
    var deletedCount = 0
    if let files = try? FileManager.default.contentsOfDirectory(
      at: tempDir,
      includingPropertiesForKeys: nil
    ) {
      for fileUrl in files {
        if (try? FileManager.default.removeItem(at: fileUrl)) != nil {
          deletedCount += 1
        }
      }
    }
    result(deletedCount)
  }

  private func handleShare(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result([
        "status": "error",
        "message": "Invalid arguments passed to iOS share.",
      ])
      return
    }

    let targetService = (args["targetService"] as? String) ?? "systemSheet"
    if targetService == "systemClipboard" {
      handleClipboardShare(args: args, result: result)
      return
    }
    if targetService == "mail" {
      handleMailtoShare(args: args, result: result)
      return
    }

    let rawItems = (args["items"] as? [[String: Any]]) ?? []
    let subject = args["subject"] as? String
    let title = args["title"] as? String
    var previewImage: UIImage?
    if let thumbData = (args["previewThumbnail"] as? FlutterStandardTypedData)?.data {
      previewImage = UIImage(data: thumbData)
    }

    var activityItems: [Any] = []
    var metadataAttached = false

    for raw in rawItems {
      let type = (raw["type"] as? String) ?? "file"
      let itemSubject = (raw["subject"] as? String) ?? subject
      if previewImage == nil,
         let itemThumb = (raw["thumbnailBytes"] as? FlutterStandardTypedData)?.data
      {
        previewImage = UIImage(data: itemThumb)
      }

      switch type {
      case "text":
        if let text = raw["text"] as? String, !text.isEmpty {
          if !metadataAttached {
            metadataAttached = true
            activityItems.append(
              XueHuaShareActivityItemSource(
                item: text,
                subject: itemSubject,
                title: title,
                previewImage: previewImage
              )
            )
          } else {
            activityItems.append(text)
          }
        }
      case "url":
        if let uriString = raw["uri"] as? String, let url = URL(string: uriString) {
          if let msg = raw["text"] as? String, !msg.isEmpty {
            activityItems.append(msg)
          }
          if !metadataAttached {
            metadataAttached = true
            activityItems.append(
              XueHuaShareActivityItemSource(
                item: url,
                subject: itemSubject,
                title: title,
                previewImage: previewImage,
                url: url
              )
            )
          } else {
            activityItems.append(url)
          }
        }
      case "memory":
        if let typedData = raw["bytes"] as? FlutterStandardTypedData {
          let fileName = (raw["fileName"] as? String) ?? "shared_file.bin"
          if let fileUrl = writeTempFile(data: typedData.data, fileName: fileName) {
            if !metadataAttached {
              metadataAttached = true
              activityItems.append(
                XueHuaShareActivityItemSource(
                  item: fileUrl,
                  subject: itemSubject,
                  title: title ?? fileName,
                  previewImage: previewImage,
                  url: fileUrl
                )
              )
            } else {
              activityItems.append(fileUrl)
            }
          }
        }
      default:
        if let filePath = raw["filePath"] as? String, !filePath.isEmpty {
          let fileUrl = URL(fileURLWithPath: filePath)
          if FileManager.default.fileExists(atPath: fileUrl.path) {
            if !metadataAttached {
              metadataAttached = true
              activityItems.append(
                XueHuaShareActivityItemSource(
                  item: fileUrl,
                  subject: itemSubject,
                  title: title ?? fileUrl.lastPathComponent,
                  previewImage: previewImage,
                  url: fileUrl
                )
              )
            } else {
              activityItems.append(fileUrl)
            }
          }
        }
      }
    }

    if activityItems.isEmpty {
      result([
        "status": "error",
        "message": "No valid share items could be prepared on iOS.",
      ])
      return
    }

    DispatchQueue.main.async {
      guard let topController = Self.topViewController() else {
        result([
          "status": "unavailable",
          "message": "Unable to locate active UIViewController to present share sheet.",
        ])
        return
      }

      let activityVC = UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: nil
      )

      var excluded: [UIActivity.ActivityType] = []
      if let excludedNames = args["excludedActivityTypes"] as? [String] {
        excluded.append(contentsOf: excludedNames.compactMap(Self.mapActivityType))
      }
      if let customExcluded = args["excludedCustomActivityIdentifiers"] as? [String] {
        excluded.append(
          contentsOf: customExcluded.map { UIActivity.ActivityType(rawValue: $0) }
        )
      }
      if !excluded.isEmpty {
        activityVC.excludedActivityTypes = excluded
      }

      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = topController.view
        if let rectMap = args["anchorRect"] as? [String: Double],
           let x = rectMap["x"],
           let y = rectMap["y"],
           let w = rectMap["width"],
           let h = rectMap["height"]
        {
          popover.sourceRect = CGRect(x: x, y: y, width: max(w, 1), height: max(h, 1))
          let edge = (args["preferredEdge"] as? String) ?? "maxY"
          popover.permittedArrowDirections = Self.mapArrowDirection(edge)
        } else {
          let bounds = topController.view.bounds
          popover.sourceRect = CGRect(
            x: bounds.midX,
            y: bounds.midY,
            width: 1,
            height: 1
          )
          popover.permittedArrowDirections = []
        }
      }

      activityVC.completionWithItemsHandler = { activityType, completed, _, activityError in
        if let error = activityError {
          result([
            "status": "error",
            "selectedActivityType": activityType?.rawValue as Any,
            "message": error.localizedDescription,
          ])
          return
        }
        if completed {
          result([
            "status": "success",
            "selectedActivityType": (activityType?.rawValue ?? "com.apple.UIKit.activity"),
            "message": "Share completed on iOS.",
          ])
        } else {
          result([
            "status": "dismissed",
            "selectedActivityType": activityType?.rawValue as Any,
            "message": "User dismissed the iOS share sheet.",
          ])
        }
      }

      topController.present(activityVC, animated: true, completion: nil)
    }
  }

  private func handleClipboardShare(args: [String: Any], result: @escaping FlutterResult) {
    let text = (args["text"] as? String) ?? (args["uri"] as? String) ?? ""
    UIPasteboard.general.string = text
    result([
      "status": "success",
      "selectedActivityType": "com.apple.UIKit.activity.CopyToPasteboard",
      "message": "Copied content to iOS pasteboard.",
    ])
  }

  private func handleMailtoShare(args: [String: Any], result: @escaping FlutterResult) {
    let recipients = ((args["emailRecipients"] as? [String]) ?? []).joined(separator: ",")
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = recipients
    var queryItems: [URLQueryItem] = []
    if let subject = (args["subject"] as? String) ?? (args["title"] as? String) {
      queryItems.append(URLQueryItem(name: "subject", value: subject))
    }
    if let body = (args["text"] as? String) ?? (args["uri"] as? String) {
      queryItems.append(URLQueryItem(name: "body", value: body))
    }
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }
    guard let mailUrl = components.url, UIApplication.shared.canOpenURL(mailUrl) else {
      result([
        "status": "unavailable",
        "message": "Mail URL scheme is not available on this iOS device.",
      ])
      return
    }
    UIApplication.shared.open(mailUrl, options: [:]) { success in
      result([
        "status": success ? "success" : "error",
        "selectedActivityType": "mailto",
        "message": success ? "Opened iOS Mail composer." : "Failed to open iOS Mail composer.",
      ])
    }
  }

  private func writeTempFile(data: Data, fileName: String) -> URL? {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
      Self.tempDirName,
      isDirectory: true
    )
    do {
      try FileManager.default.createDirectory(
        at: tempDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
      let sanitized = fileName.replacingOccurrences(
        of: "[^a-zA-Z0-9._-]",
        with: "_",
        options: .regularExpression
      )
      let fileUrl = tempDir.appendingPathComponent(
        "\(Int(Date().timeIntervalSince1970 * 1000))_\(sanitized)"
      )
      try data.write(to: fileUrl, options: .atomic)
      return fileUrl
    } catch {
      return nil
    }
  }

  private static func mapArrowDirection(_ edge: String) -> UIPopoverArrowDirection {
    switch edge {
    case "minX":
      return .right
    case "minY":
      return .down
    case "maxX":
      return .left
    case "maxY":
      return .up
    default:
      return .any
    }
  }

  private static func mapActivityType(_ name: String) -> UIActivity.ActivityType? {
    switch name {
    case "postToFacebook":
      return .postToFacebook
    case "postToTwitter":
      return .postToTwitter
    case "postToWeibo":
      return .postToWeibo
    case "message":
      return .message
    case "mail":
      return .mail
    case "print":
      return .print
    case "copyToPasteboard":
      return .copyToPasteboard
    case "assignToContact":
      return .assignToContact
    case "saveToCameraRoll":
      return .saveToCameraRoll
    case "addToReadingList":
      return .addToReadingList
    case "postToFlickr":
      return .postToFlickr
    case "postToVimeo":
      return .postToVimeo
    case "postToTencentWeibo":
      return .postToTencentWeibo
    case "airDrop":
      return .airDrop
    case "openInIBooks":
      return .openInIBooks
    case "markupAsPDF":
      return .markupAsPDF
    case "sharePlay":
      if #available(iOS 15.4, *) {
        return .sharePlay
      }
      return nil
    default:
      return nil
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

    let keyWindow = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
      ?? scenes.flatMap { $0.windows }.first

    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
