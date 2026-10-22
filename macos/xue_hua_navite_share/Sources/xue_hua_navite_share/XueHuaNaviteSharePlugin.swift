import Cocoa
import FlutterMacOS

/// macOS implementation of `xue_hua_navite_share`.
///
/// Features:
/// - Native `NSSharingServicePicker` anchored accurately to Flutter widget coordinates
///   (handling AppKit vs Flutter coordinate origin conversion).
/// - Direct targeted service invocation (`NSSharingService`) for AirDrop, Messages,
///   Mail (with recipients & subject), Safari Reading List, System Pasteboard,
///   and Finder file reveal (`NSWorkspace.shared.activateFileViewerSelecting`).
/// - Service filtering (`sharingServicePicker(_:sharingServicesForItems:proposedSharingServices:)`).
/// - Full delegate tracking (`NSSharingServicePickerDelegate` & `NSSharingServiceDelegate`)
///   to distinguish service completion, user dismissal, and sharing errors.
public class XueHuaNaviteSharePlugin: NSObject,
  FlutterPlugin,
  NSSharingServicePickerDelegate,
  NSSharingServiceDelegate
{
  private static let channelName = "xue_hua_navite_share"
  private static let tempDirName = "xue_hua_share_temp"

  private static let knownServiceNames: [NSSharingService.Name] = [
    .sendViaAirDrop,
    .composeMessage,
    .composeEmail,
    .addToSafariReadingList,
    .cloudSharing,
  ]

  private weak var registrar: FlutterPluginRegistrar?
  private var pendingResult: FlutterResult?
  private var activePicker: NSSharingServicePicker?
  private var activeService: NSSharingService?
  private var chosenServiceName: String?
  private var excludedServiceNames: Set<String> = []
  private var pendingSubject: String?
  private var pendingRecipients: [String] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    let instance = XueHuaNaviteSharePlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public init(registrar: FlutterPluginRegistrar? = nil) {
    self.registrar = registrar
    super.init()
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
    let probeItems: [Any] = ["https://flutter.dev"]
    let services = NSSharingService.sharingServices(forItems: probeItems)
    var serviceNames = services.map { Self.identifier(for: $0) }
    serviceNames.append(contentsOf: ["systemClipboard", "fileExplorer"])

    result([
      "platform": "macos",
      "supportsSystemShareSheet": true,
      "supportsFileSharing": true,
      "supportsMultipleFiles": true,
      "supportsMemoryBytesSharing": true,
      "supportsTargetedServices": true,
      "supportsAnchorPopover": true,
      "supportsExcludedActivities": true,
      "supportsChosenTargetCallback": true,
      "availableServices": Array(Set(serviceNames)).sorted(),
    ])
  }

  private func handleCanShare(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(false)
      return
    }
    let items = prepareShareItems(from: args)
    if items.isEmpty {
      result(false)
      return
    }
    let targetService = (args["targetService"] as? String) ?? "systemSheet"
    if targetService == "systemClipboard" || targetService == "fileExplorer" {
      result(true)
      return
    }
    if targetService != "systemSheet",
       let serviceName = resolveServiceName(targetService: targetService, args: args),
       let service = NSSharingService(named: serviceName)
    {
      result(service.canPerform(withItems: items))
      return
    }
    let available = NSSharingService.sharingServices(forItems: items)
    result(!available.isEmpty || ((args["fallbackToClipboard"] as? Bool) ?? true))
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
        "message": "Invalid arguments passed to macOS share.",
      ])
      return
    }

    let targetService = (args["targetService"] as? String) ?? "systemSheet"
    let shareItems = prepareShareItems(from: args)
    if shareItems.isEmpty {
      result([
        "status": "error",
        "message": "No valid share items could be prepared on macOS.",
      ])
      return
    }

    // 1. Direct System Clipboard share
    if targetService == "systemClipboard" {
      copyItemsToPasteboard(shareItems, result: result, isFallback: false)
      return
    }

    // 2. Direct Finder Reveal (`fileExplorer`)
    if targetService == "fileExplorer" {
      let fileUrls = shareItems.compactMap { $0 as? URL }.filter { $0.isFileURL }
      if fileUrls.isEmpty {
        result([
          "status": "unavailable",
          "message": "No local files in share payload to reveal in Finder.",
        ])
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting(fileUrls)
      result([
        "status": "success",
        "selectedActivityType": "com.apple.Finder",
        "message": "Revealed \(fileUrls.count) file(s) in macOS Finder.",
      ])
      return
    }

    pendingSubject = (args["subject"] as? String) ?? (args["title"] as? String)
    pendingRecipients = (args["emailRecipients"] as? [String]) ?? []
    excludedServiceNames = buildExcludedServiceSet(args: args)

    // 3. Direct targeted NSSharingService (AirDrop, Mail, Messages, Reading List, Custom)
    if targetService != "systemSheet" {
      guard let serviceName = resolveServiceName(targetService: targetService, args: args),
            let service = NSSharingService(named: serviceName),
            service.canPerform(withItems: shareItems)
      else {
        if (args["fallbackToClipboard"] as? Bool) ?? true {
          copyItemsToPasteboard(shareItems, result: result, isFallback: true)
        } else {
          result([
            "status": "unavailable",
            "message": "Requested macOS sharing service '\(targetService)' cannot perform with the provided items.",
          ])
        }
        return
      }

      DispatchQueue.main.async {
        self.completePendingAsSuperseded()
        self.pendingResult = result
        self.chosenServiceName = serviceName.rawValue
        self.activeService = service
        service.delegate = self
        if let subject = self.pendingSubject {
          service.subject = subject
        }
        if !self.pendingRecipients.isEmpty {
          service.recipients = self.pendingRecipients
        }
        service.perform(withItems: shareItems)
      }
      return
    }

    // 4. Native NSSharingServicePicker popover anchored to the Flutter view
    DispatchQueue.main.async {
      guard let anchorView = self.resolveAnchorView() else {
        if (args["fallbackToClipboard"] as? Bool) ?? true {
          self.copyItemsToPasteboard(shareItems, result: result, isFallback: true)
        } else {
          result([
            "status": "unavailable",
            "message": "No active macOS NSView available to anchor NSSharingServicePicker.",
          ])
        }
        return
      }

      self.completePendingAsSuperseded()
      self.pendingResult = result
      self.chosenServiceName = nil

      let picker = NSSharingServicePicker(items: shareItems)
      picker.delegate = self
      self.activePicker = picker

      let rect = self.resolveAnchorRect(args: args, in: anchorView)
      let edge = Self.mapPreferredEdge(
        (args["preferredEdge"] as? String) ?? "maxY",
        isFlipped: anchorView.isFlipped
      )
      picker.show(relativeTo: rect, of: anchorView, preferredEdge: edge)
    }
  }

  private func prepareShareItems(from args: [String: Any]) -> [Any] {
    let rawItems = (args["items"] as? [[String: Any]]) ?? []
    var items: [Any] = []

    for raw in rawItems {
      let type = (raw["type"] as? String) ?? "file"
      switch type {
      case "text":
        if let text = raw["text"] as? String, !text.isEmpty {
          items.append(text)
        }
      case "url":
        if let msg = raw["text"] as? String, !msg.isEmpty {
          items.append(msg)
        }
        if let uriStr = raw["uri"] as? String, let url = URL(string: uriStr) {
          items.append(url)
        }
      case "memory":
        if let typedData = raw["bytes"] as? FlutterStandardTypedData {
          let fileName = (raw["fileName"] as? String) ?? "shared_file.bin"
          if let fileUrl = writeTempFile(data: typedData.data, fileName: fileName) {
            items.append(fileUrl)
          }
        }
      default:
        if let filePath = raw["filePath"] as? String, !filePath.isEmpty {
          let fileUrl = URL(fileURLWithPath: filePath)
          if FileManager.default.fileExists(atPath: fileUrl.path) {
            items.append(fileUrl)
          }
        }
      }
    }
    return items
  }

  private func copyItemsToPasteboard(
    _ items: [Any],
    result: @escaping FlutterResult,
    isFallback: Bool
  ) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    var objectsToWrite: [NSPasteboardWriting] = []
    for item in items {
      if let str = item as? String {
        objectsToWrite.append(str as NSString)
      } else if let url = item as? URL {
        objectsToWrite.append(url as NSURL)
      }
    }
    let success = pasteboard.writeObjects(objectsToWrite)
    result([
      "status": success ? (isFallback ? "fallbackExecuted" : "success") : "error",
      "selectedActivityType": "com.apple.pasteboard",
      "message": success
        ? "Copied shared items to macOS system pasteboard."
        : "Failed to write items to macOS pasteboard.",
    ])
  }

  private func resolveAnchorView() -> NSView? {
    if let view = registrar?.view {
      return view
    }
    return NSApplication.shared.keyWindow?.contentView
      ?? NSApplication.shared.mainWindow?.contentView
      ?? NSApplication.shared.windows.first?.contentView
  }

  private func resolveAnchorRect(args: [String: Any], in view: NSView) -> NSRect {
    let bounds = view.bounds
    guard let rectMap = args["anchorRect"] as? [String: Double],
          let x = rectMap["x"],
          let y = rectMap["y"],
          let w = rectMap["width"],
          let h = rectMap["height"]
    else {
      return NSRect(x: bounds.midX - 1, y: bounds.midY - 1, width: 2, height: 2)
    }

    let safeW = max(w, 1.0)
    let safeH = max(h, 1.0)
    if view.isFlipped {
      return NSRect(x: x, y: y, width: safeW, height: safeH)
    } else {
      // Convert Flutter top-left origin to AppKit bottom-left origin
      let flippedY = bounds.height - y - safeH
      return NSRect(x: x, y: max(0, flippedY), width: safeW, height: safeH)
    }
  }

  private static func mapPreferredEdge(_ edge: String, isFlipped: Bool) -> NSRectEdge {
    switch edge {
    case "minX":
      return .minX
    case "maxX":
      return .maxX
    case "minY":
      return isFlipped ? .minY : .maxY
    case "maxY":
      return isFlipped ? .maxY : .minY
    default:
      return isFlipped ? .maxY : .minY
    }
  }

  private func resolveServiceName(
    targetService: String,
    args: [String: Any]
  ) -> NSSharingService.Name? {
    switch targetService {
    case "airDrop":
      return .sendViaAirDrop
    case "messages":
      return .composeMessage
    case "mail":
      return .composeEmail
    case "readingList":
      return .addToSafariReadingList
    case "custom":
      if let customName = args["customServiceName"] as? String, !customName.isEmpty {
        return NSSharingService.Name(customName)
      }
      return nil
    default:
      return nil
    }
  }

  private static func identifier(for service: NSSharingService) -> String {
    for name in knownServiceNames {
      if let candidate = NSSharingService(named: name), candidate == service {
        return name.rawValue
      }
    }
    return service.title
  }

  private func buildExcludedServiceSet(args: [String: Any]) -> Set<String> {
    var set = Set<String>()
    if let excludedTypes = args["excludedActivityTypes"] as? [String] {
      for item in excludedTypes {
        switch item {
        case "airDrop":
          set.insert(NSSharingService.Name.sendViaAirDrop.rawValue)
        case "message":
          set.insert(NSSharingService.Name.composeMessage.rawValue)
        case "mail":
          set.insert(NSSharingService.Name.composeEmail.rawValue)
        case "addToReadingList":
          set.insert(NSSharingService.Name.addToSafariReadingList.rawValue)
        default:
          break
        }
      }
    }
    if let customIds = args["excludedCustomActivityIdentifiers"] as? [String] {
      set.formUnion(customIds)
    }
    return set
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

  private func completePendingAsSuperseded() {
    if let pending = pendingResult {
      pendingResult = nil
      pending([
        "status": "dismissed",
        "message": "Superseded by a newer macOS share request.",
      ])
    }
  }

  // MARK: - NSSharingServicePickerDelegate

  public func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    sharingServicesForItems items: [Any],
    proposedSharingServices proposedServices: [NSSharingService]
  ) -> [NSSharingService] {
    guard !excludedServiceNames.isEmpty else {
      return proposedServices
    }
    return proposedServices.filter { service in
      let id = Self.identifier(for: service)
      return !excludedServiceNames.contains(id) && !excludedServiceNames.contains(service.title)
    }
  }

  public func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    delegateFor sharingService: NSSharingService
  ) -> NSSharingServiceDelegate? {
    if let subject = pendingSubject {
      sharingService.subject = subject
    }
    if !pendingRecipients.isEmpty {
      sharingService.recipients = pendingRecipients
    }
    return self
  }

  public func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker,
    didChoose service: NSSharingService?
  ) {
    activePicker = nil
    guard let chosen = service else {
      if let pending = pendingResult {
        pendingResult = nil
        pending([
          "status": "dismissed",
          "message": "User dismissed the macOS NSSharingServicePicker.",
        ])
      }
      return
    }
    chosenServiceName = Self.identifier(for: chosen)
    activeService = chosen
  }

  // MARK: - NSSharingServiceDelegate

  public func sharingService(
    _ sharingService: NSSharingService,
    sourceWindowForShareItems items: [Any],
    sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>
  ) -> NSWindow? {
    return registrar?.view?.window
      ?? NSApplication.shared.keyWindow
      ?? NSApplication.shared.mainWindow
  }

  public func sharingService(
    _ sharingService: NSSharingService,
    didShareItems items: [Any]
  ) {
    activeService = nil
    guard let pending = pendingResult else { return }
    pendingResult = nil
    pending([
      "status": "success",
      "selectedActivityType": chosenServiceName ?? Self.identifier(for: sharingService),
      "message": "Shared successfully via macOS NSSharingService.",
    ])
  }

  public func sharingService(
    _ sharingService: NSSharingService,
    didFailToShareItems items: [Any],
    error: Error
  ) {
    activeService = nil
    guard let pending = pendingResult else { return }
    pendingResult = nil
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
      pending([
        "status": "dismissed",
        "selectedActivityType": chosenServiceName ?? Self.identifier(for: sharingService),
        "message": "User cancelled the macOS sharing service dialog.",
      ])
    } else {
      pending([
        "status": "error",
        "selectedActivityType": chosenServiceName ?? Self.identifier(for: sharingService),
        "message": error.localizedDescription,
      ])
    }
  }
}
