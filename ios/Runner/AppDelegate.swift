import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // PROČ: Bez registerForRemoteNotifications() systém často nevygeneruje APNs device token.
    // Firebase pak na iOS vrací null z getAPNSToken() / getToken() — žádný zápis do Supabase.
    // (Dialog oprávnění z Flutteru sám o sobě APNs registraci nezaručuje.)
    application.registerForRemoteNotifications()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
