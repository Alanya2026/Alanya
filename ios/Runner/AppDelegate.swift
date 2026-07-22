import Flutter
import UIKit
import PushKit

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Phase 6.1 : PushKit VoIP — activer via IOS_VOIP_V2 côté build/config
    if ProcessInfo.processInfo.environment["IOS_VOIP_V2"] == "1" {
      registerVoipPush()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerVoipPush() {
    voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry?.delegate = self
    voipRegistry?.desiredPushTypes = [.voIP]
  }

  // MARK: - PKPushRegistryDelegate (Phase 6 — implémentation CallKit complète à suivre)

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    NSLog("[PushKit] voip token len=%d", token.count)
    // Envoyer token au backend via canal Flutter MethodChannel (Phase 6.1)
  }

  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    NSLog("[PushKit] incoming voip push")
    // Phase 6.3 : CXProvider reportNewIncomingCall immédiat
    completion()
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    NSLog("[PushKit] token invalidated")
  }
}
