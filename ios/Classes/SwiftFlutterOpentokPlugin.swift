import Flutter
import UIKit

public class SwiftFlutterOpentokPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let openTokViewFactory = FlutterOpenTokViewFactory.init(registrar: registrar)

        registrar.register(openTokViewFactory as FlutterPlatformViewFactory, withId: "OpenTokRendererView")
    }

}
