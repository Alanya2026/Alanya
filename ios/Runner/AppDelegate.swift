import Flutter
import UIKit
import PushKit
import UserNotifications
import flutter_callkit_incoming

// MARK: - Actions notification iOS (Phase 5.2)

private enum NotificationActionHandler {
  static let tokenKey = "notif_action_access_token"
  static let apiBaseKey = "notif_action_api_base"
  static let categoryId = "ALANYA_MESSAGE"
  static let actionReply = "REPLY"
  static let actionMarkRead = "MARK_AS_READ"

  static func registerCategories() {
    let reply = UNTextInputNotificationAction(
      identifier: actionReply,
      title: "Répondre",
      options: [],
      textInputButtonTitle: "Envoyer",
      textInputPlaceholder: "Message"
    )
    let markRead = UNNotificationAction(
      identifier: actionMarkRead,
      title: "Marquer lu",
      options: [.destructive]
    )
    let category = UNNotificationCategory(
      identifier: categoryId,
      actions: [reply, markRead],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  static func conversationId(from userInfo: [AnyHashable: Any]) -> Int {
    if let s = userInfo["conversationId"] as? String, let v = Int(s) { return v }
    if let n = userInfo["conversationId"] as? NSNumber { return n.intValue }
    if let s = userInfo["gcm.notification.conversationId"] as? String, let v = Int(s) { return v }
    return 0
  }

  static func handle(response: UNNotificationResponse) -> Bool {
    let convId = conversationId(from: response.notification.request.content.userInfo)
    switch response.actionIdentifier {
    case actionReply:
      guard let textResponse = response as? UNTextInputNotificationResponse else { return true }
      let text = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty, convId > 0 else { return true }
      let clientId = "notif_ios_\(Int(Date().timeIntervalSince1970 * 1000))_\(convId)"
      sendReply(conversationId: convId, text: text, clientId: clientId)
      return true
    case actionMarkRead:
      guard convId > 0 else { return true }
      markRead(conversationId: convId)
      removeThreadNotifications(conversationId: convId)
      return true
    default:
      return false
    }
  }

  private static func credentials() -> (token: String, base: String)? {
    let defaults = UserDefaults.standard
    guard let token = defaults.string(forKey: tokenKey), !token.isEmpty,
          let base = defaults.string(forKey: apiBaseKey), !base.isEmpty else {
      NSLog("[NotifAction] credentials manquantes")
      return nil
    }
    return (token, base)
  }

  static func markRead(conversationId: Int) {
    guard let creds = credentials() else { return }
    let urlString = "\(creds.base.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/conversations/\(conversationId)/read"
    guard let url = URL(string: urlString) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: request) { _, response, error in
      if let error = error {
        NSLog("[NotifAction] markRead error: \(error.localizedDescription)")
        return
      }
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      NSLog("[NotifAction] markRead HTTP \(code) conv=\(conversationId)")
    }.resume()
  }

  static func sendReply(conversationId: Int, text: String, clientId: String) {
    guard let creds = credentials() else { return }
    let urlString = "\(creds.base.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/conversations/\(conversationId)/messages"
    guard let url = URL(string: urlString) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
    let body: [String: Any] = ["content": text, "type": 0, "clientId": clientId]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request) { _, response, error in
      if let error = error {
        NSLog("[NotifAction] reply error: \(error.localizedDescription)")
        return
      }
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      NSLog("[NotifAction] reply HTTP \(code) conv=\(conversationId)")
    }.resume()
  }

  static func removeThreadNotifications(conversationId: Int) {
    let thread = "conv_\(conversationId)"
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      let ids = notifications.compactMap { notif -> String? in
        if notif.request.content.threadIdentifier == thread {
          return notif.request.identifier
        }
        if conversationId(from: notif.request.content.userInfo) == conversationId {
          return notif.request.identifier
        }
        return nil
      }
      if !ids.isEmpty {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
      }
    }
  }
}

// MARK: - PushKit VoIP (Phase 6.1)

private enum VoipCallHandler {
  static func stringValue(_ dict: [AnyHashable: Any], _ key: String) -> String {
    if let s = dict[key] as? String { return s }
    if let n = dict[key] as? NSNumber { return n.stringValue }
    if let b = dict[key] as? Bool { return b ? "true" : "false" }
    return ""
  }

  static func isVideo(_ dict: [AnyHashable: Any]) -> Bool {
    let raw = stringValue(dict, "isVideo").lowercased()
    return raw == "true" || raw == "1"
  }

  static func buildCallData(from payload: PKPushPayload) -> flutter_callkit_incoming.Data? {
    let dict = payload.dictionaryPayload
    let pushType = stringValue(dict, "type")
    if pushType == "call_ended" {
      return nil
    }
    let callId = stringValue(dict, "callId")
    let roomId = stringValue(dict, "roomId")
    let id = !callId.isEmpty ? callId : (!roomId.isEmpty ? roomId : UUID().uuidString)
    let callerName = stringValue(dict, "callerName").isEmpty
      ? (stringValue(dict, "nameCaller").isEmpty ? "Appel entrant" : stringValue(dict, "nameCaller"))
      : stringValue(dict, "callerName")
    let callerId = stringValue(dict, "callerId").isEmpty
      ? stringValue(dict, "handle")
      : stringValue(dict, "callerId")
    let photo = stringValue(dict, "photo").isEmpty
      ? stringValue(dict, "callerPhoto")
      : stringValue(dict, "photo")

    let data = flutter_callkit_incoming.Data(
      id: id,
      nameCaller: callerName,
      handle: callerId.isEmpty ? "unknown" : callerId,
      type: isVideo(dict) ? 1 : 0
    )
    data.appName = "Alanya"
    if !photo.isEmpty {
      data.avatar = photo
    }
    data.extra = [
      "callId": callId.isEmpty ? id : callId,
      "callerId": callerId,
      "callerName": callerName,
      "callerPhoto": photo,
      "isVideo": isVideo(dict),
      "roomId": roomId,
    ] as NSDictionary
    return data
  }

  static func endCall(from payload: PKPushPayload) {
    let dict = payload.dictionaryPayload
    let callId = stringValue(dict, "callId")
    let roomId = stringValue(dict, "roomId")
    let id = !callId.isEmpty ? callId : roomId
    guard !id.isEmpty else { return }
    let data = flutter_callkit_incoming.Data(
      id: id,
      nameCaller: "",
      handle: "",
      type: 0
    )
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
    NSLog("[PushKit] call_ended voip dismiss id=%@", id)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NotificationActionHandler.registerCategories()
    registerVoipPush()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if NotificationActionHandler.handle(response: response) {
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  private func registerVoipPush() {
    voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry?.delegate = self
    voipRegistry?.desiredPushTypes = [.voIP]
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    NSLog("[PushKit] voip token len=%d", token.count)
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let pushType = VoipCallHandler.stringValue(
      payload.dictionaryPayload,
      "type"
    )
    if pushType == "call_ended" {
      VoipCallHandler.endCall(from: payload)
      completion()
      return
    }

    guard let data = VoipCallHandler.buildCallData(from: payload) else {
      NSLog("[PushKit] payload appel invalide")
      completion()
      return
    }

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true) {
      completion()
    }
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    NSLog("[PushKit] token invalidated")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }
}
