import Flutter
import UIKit

public class SwiftFlutterOpentokPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_opentok", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterOpentokPlugin()
        let openTokViewFactory = FlutterOpenTokViewFactory()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(openTokViewFactory as FlutterPlatformViewFactory, withId: "OpenTokRendererView")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "create") {
            guard let args = call.arguments else {
                return
            }
            
            if let methodArgs = args as? [String: Any],
                let apiKey = methodArgs["apiKey"] as? String,
                let sessionId = methodArgs["sessionId"] as? String,
                let token = methodArgs["token"] as? String {
                print("Params received on iOS = \(apiKey), \(sessionId), \(token)")
                result("yay");
            } else {
                result("iOS could not extract flutter arguments in method: (sendParams)")
            }
        } else if (call.method == "destroy") {
            result("destroy")
        } else if call.method == "getPlatformVersion" {
            result("Running on: iOS " + UIDevice.current.systemVersion)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}
