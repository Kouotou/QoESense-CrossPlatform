import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // After super, so nothing replaces the notification delegate; before returning, as the
    // BGTask registration requires. Starts the headless collector engine if collection is on,
    // whatever launched the app (the participant, a location event, a BGTask, a notification).
    IosCollectorHost.shared.launch()
    return launched
  }

  /// The UI engine. It shows the screens and never collects.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QoESenseTelemetryHostApi") {
      let messenger = registrar.messenger()
      TelemetryHostApiSetup.setUp(binaryMessenger: messenger, api: IOSCapabilityReporter())
      IosCollectorApiSetup.setUp(binaryMessenger: messenger, api: IosCollectorHost.shared)
      IosCollectorHost.shared.attachUi(SurveyUiEvents(binaryMessenger: messenger))
    }
  }
}
