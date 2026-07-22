import UserNotifications

/// Notification Service Extension (Phase 5.3) — template à ajouter comme target Xcode.
/// App Group : group.com.example.talkyFlutter (aligné Runner.entitlements).
/// Backend : IOS_RICH_NSE=true + senderAvatar dans le payload APNs (mutable-content).
class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let content = bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    guard let avatarUrl = content.userInfo["senderAvatar"] as? String,
          let url = URL(string: avatarUrl),
          url.scheme == "http" || url.scheme == "https" else {
      contentHandler(content)
      return
    }

    URLSession.shared.downloadTask(with: url) { [weak self] tempUrl, _, _ in
      guard let self = self, let content = self.bestAttemptContent else { return }
      defer { contentHandler(content) }

      guard let tempUrl = tempUrl else { return }
      let dest = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-\(UUID().uuidString).jpg")
      try? FileManager.default.moveItem(at: tempUrl, to: dest)
      if let attachment = try? UNNotificationAttachment(identifier: "avatar", url: dest, options: nil) {
        content.attachments = [attachment]
      }
    }.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler, let content = bestAttemptContent {
      contentHandler(content)
    }
  }
}
