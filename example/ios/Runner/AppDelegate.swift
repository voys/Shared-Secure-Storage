import Flutter
import UIKit
import shared_secure_storage

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let key = "example.secret"

  private var valueReadBeforeFlutter: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // No Flutter engine exists yet, this is what e.g. a PushKit handler would do.
    valueReadBeforeFlutter = try? SharedSecureStorage.shared.read(AppDelegate.key)
    NSLog("SharedSecureStorage: read before Flutter started: %@", valueReadBeforeFlutter ?? "nil")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Only here so the example and its tests can show what native code sees.
    let storage = SharedSecureStorage.shared

    FlutterMethodChannel(
      name: "example/native",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "readBeforeFlutter":
        result(self?.valueReadBeforeFlutter)
      case "read":
        result(try? storage.read(call.arguments as! String))
      case "write":
        let arguments = call.arguments as! [String]
        try? storage.write(arguments[1], for: arguments[0])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
