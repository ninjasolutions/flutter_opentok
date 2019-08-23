//
//  FlutterOpenTokViewFactory.swift
//  flutter_opentok
//
//  Created by Genert Org on 23/08/2019.
//

import Foundation

class FlutterOpenTokViewFactory : NSObject, FlutterPlatformViewFactory {
    private let registrar: FlutterPluginRegistrar!
    
    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let viewController: FlutterOpenTokViewController! = FlutterOpenTokViewController(frame:frame,
                                                                                         viewIdentifier:viewId,
                                                                                         arguments:args,
                                                                                         registrar: self.registrar)
        viewController.setup()
        
        return viewController
    }
    
}
