//
//  FlutterOpenTokViewFactory.swift
//  flutter_opentok
//
//  Created by Genert Org on 23/08/2019.
//

import Foundation

public protocol FlutterViewControllerImpl {
    func setup()

    func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult)

    func channelInvokeMethod(_ method: String, arguments: Any?)
}

class FlutterOpenTokViewFactory: NSObject, FlutterPlatformViewFactory {
    private let registrar: FlutterPluginRegistrar!

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        // Setup logging.
        if let arguments = args as? [String: Any],
            let loggingEnabled = arguments["loggingEnabled"] as? Bool {
            SwiftFlutterOpentokPlugin.loggingEnabled = loggingEnabled
        }

        let viewController: FlutterOpenTokViewController! = FlutterOpenTokViewController(frame: frame,
                                                                                         viewIdentifier: viewId,
                                                                                         arguments: args,
                                                                                         registrar: registrar)
        viewController.setup()

        return viewController
    }
}
