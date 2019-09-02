//
//  FlutterOpenTokView.swift
//  flutter_opentok
//
//  Created by Genert Org on 22/08/2019.
//

import os
import Foundation
import OpenTok

class FlutterOpenTokViewController: NSObject, FlutterPlatformView {
    private var openTokView: UIView!
    private let registrar: FlutterPluginRegistrar!
    private let frame : CGRect
    private let viewId : Int64
    private var channel : FlutterMethodChannel!
    
    var session: OTSession?
    
    var publisher: OTPublisher?
    
    var subscriber: OTSubscriber?
    
    var screenHeight: Int!
    var screenWidth: Int!
    
    public init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, registrar: FlutterPluginRegistrar) {
        let channelName = String(format: "plugins.indoor.solutions/opentok_%lld", viewId)
        
        self.frame = frame
        self.registrar = registrar
        self.viewId = viewId
        
        channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        
        openTokView = UIView(frame: self.frame)
        openTokView.isOpaque = false
        openTokView.backgroundColor = UIColor.black
        
        print("here?")
        
        if let arguments = args as? [String: Any],
            let width = arguments["width"] as? Int,
            let height = arguments["height"] as? Int {
            screenHeight = height
            screenWidth = width
        } else {
            screenHeight = 150
            screenWidth = 150
        }
        
        super.init()
    }
    
    deinit {
        print("[DEINIT] FlutterOpenTokViewController")
    }
    
    func setup() {
        self.channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self?.onMethodCall(call: call, result: result)
        })
    }
    
    func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "create") {
            guard let args = call.arguments else {
                return
            }
            
            if let methodArgs = args as? [String: Any],
                let apiKey = methodArgs["apiKey"] as? String,
                let sessionId = methodArgs["sessionId"] as? String,
                let token = methodArgs["token"] as? String {
                create(apiKey: apiKey, sessionId: sessionId, token: token)
                result(nil);
            } else {
                result("iOS could not extract flutter arguments in method: (create)")
            }
        } else if (call.method == "destroy") {
            destroy()
            result(nil)
        } else if call.method == "enableAudio" {
            unmutePublisherAudio()
            unmuteSubscriberAudio()
            result(nil)
        } else if call.method == "disableAudio" {
            mutePublisherAudio()
            muteSubscriberAudio()
            result(nil)
        } else if call.method == "enablePublisherAudio" {
            unmutePublisherAudio()
            result(nil)
        } else if call.method == "disablePublisherAudio" {
            mutePublisherAudio()
            result(nil)
        } else if call.method == "enableSubscriberAudio" {
            unmuteSubscriberAudio()
            result(nil)
        } else if call.method == "disableSubscriberAudio" {
            muteSubscriberAudio()
            result(nil)
        } else if call.method == "changePublisherCameraPositionToFront" {
            changePublisherCameraPositionToFront()
            result(nil)
        } else if call.method == "changePublisherCameraPositionToBack" {
            changePublisherCameraPositionToBack()
            result(nil)
        } else if call.method == "switchCamera" {
            if self.publisher?.cameraPosition == AVCaptureDevice.Position.back {
                changePublisherCameraPositionToFront()
            } else {
                changePublisherCameraPositionToBack()
            }
            
            result(nil)
        } else if call.method == "getSdkVersion" {
            result(OPENTOK_LIBRARY_VERSION)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func view() -> UIView {
        return openTokView
    }
    
    func create(apiKey: String, sessionId: String, token: String) {
        session = OTSession(apiKey: apiKey, sessionId: sessionId, delegate: self)!
        
        doConnect(token)
    }
    
    func destroy() {
        if self.session != nil {
            unpublish()
            unsubscribe()
            disconnectSession()
        }
    }
    
    func unpublish() {
        if self.publisher != nil {
            self.session?.unpublish(self.publisher!, error: nil)
            self.publisher = nil
        }
    }
    
    func subscribe(toStream stream: OTStream) {
        self.subscriber = OTSubscriber(stream: stream, delegate: self)
        self.session?.subscribe(self.subscriber!, error: nil)
    }
    
    func unsubscribe() {
        if self.subscriber != nil {
            self.session?.unsubscribe(self.subscriber!, error: nil)
            self.subscriber = nil
        }
    }
    
    func disconnectSession() {
        if self.session != nil {
            self.session?.disconnect(nil)
            self.session = nil
        }
    }
    
    func mutePublisherAudio() {
        publisher?.publishAudio = false;
    }
    
    func unmutePublisherAudio() {
        publisher?.publishAudio = true;
    }
    
    func muteSubscriberAudio() {
        subscriber?.subscribeToAudio = false;
    }
    
    func unmuteSubscriberAudio() {
        subscriber?.subscribeToAudio = true;
    }
    
    func changePublisherCameraPositionToFront() {
        self.publisher?.cameraPosition = .front
    }
    
    func changePublisherCameraPositionToBack() {
        self.publisher?.cameraPosition = .back
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    private func doConnect(_ token: String) {
        var error: OTError?
        defer {
            process(error: error)
        }
        
        session?.connect(withToken: token, error: &error)
    }
    
    fileprivate func process(error err: OTError?) {
        if let e = err {
            print(e.localizedDescription)
        }
    }
    
    func channelInvokeMethod(_ method: String, arguments: Any?) {
        channel.invokeMethod(method, arguments: arguments) {
            (result: Any?) -> Void in
            if #available(iOS 10.0, *) {
                if let error = result as? FlutterError {
                    os_log("%@ failed: %@", type: .error, method, error.message!)
                } else if FlutterMethodNotImplemented.isEqual(result) {
                    os_log("%@ not implemented", type: .error)
                }
            }
        }
    }
}

// MARK: - OTSession delegate callbacks
extension FlutterOpenTokViewController: OTSessionDelegate {
    // The client connected to the OpenTok session.
    func sessionDidConnect(_ session: OTSession) {
        channelInvokeMethod("onSessionConnect", arguments: nil)

        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        guard let publisher = OTPublisher(delegate: self, settings: settings) else {
            return
        }
        
        publisher.cameraPosition = .front
        
        var error: OTError?
        session.publish(publisher, error: &error)
        guard error == nil else {
            print(error!)
            return
        }
        
        guard let publisherView = publisher.view else {
            return
        }
        
        publisherView.frame = CGRect(x: 0, y: 0, width: self.screenWidth, height: self.screenHeight)
        
        openTokView.addSubview(publisherView)
    }
    
    // The client disconnected from the OpenTok session.
    func sessionDidDisconnect(_ session: OTSession) {
        channelInvokeMethod("onSessionDisconnect", arguments: nil)
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("The client failed to connect to the OpenTok session: \(error).")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("A stream was created in the session.")
    }
    
    // A stream was destroyed in the session.
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        self.disconnectSession()
    }
}

// MARK: - OTPublisher delegate callbacks
extension FlutterOpenTokViewController: OTPublisherDelegate {
    
    public func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print(#function, stream)
    }
    
    public func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        print(#function, stream)
        
        self.unpublish()
    }
    
    public func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print(#function, error)
    }
    
    public func publisher(_ publisher: OTPublisher, didChangeCameraPosition position: AVCaptureDevice.Position) {
        print(#function, position)
    }
    
}

// MARK: - OTSubscriberDelegate callbacks
extension FlutterOpenTokViewController: OTSubscriberDelegate {
    
    public func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
        print(#function)
    }
    
    public func subscriberDidReconnect(toStream subscriber: OTSubscriberKit) {
        print(#function)
    }
    
    public func subscriberDidDisconnect(fromStream subscriber: OTSubscriberKit) {
        print(#function)
        self.unsubscribe()
    }
    
    public func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print(#function, error)
    }
    
    public func subscriberVideoEnabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        print(#function, reason)
    }
    
    public func subscriberVideoDisabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        print(#function, reason)
    }
}
