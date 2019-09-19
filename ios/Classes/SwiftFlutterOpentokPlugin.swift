import Flutter
import UIKit

public class SwiftFlutterOpentokPlugin: NSObject, FlutterPlugin {
    public static var loggingEnabled: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let openTokViewFactory = FlutterOpenTokViewFactory(registrar: registrar)

        registrar.register(openTokViewFactory as FlutterPlatformViewFactory, withId: "OpenTokRendererView")
    }
}
