//
//  FlutterOpenTokView.swift
//  flutter_opentok
//
//  Created by Genert Org on 22/08/2019.
//

import Foundation
import OpenTok
import os
import SnapKit

class FlutterOpenTokViewController: NSObject, FlutterPlatformView {
    private var openTokView: UIView!
    private let registrar: FlutterPluginRegistrar!
    private let frame: CGRect
    private let viewId: Int64
    private var channel: FlutterMethodChannel!

    // Publisher settings
    var publisherSettings: PublisherSettings?

    var screenHeight: Int?
    var screenWidth: Int?
    
    var publisherHeight: Int = 250
    var publisherWidth: Int = 180

    var enablePublisherVideo: Bool?

    /// Is audio switched to speaker
    fileprivate(set) var switchedToSpeaker: Bool = true

    /// Instance providing us VoIP
    fileprivate var provider: VoIPProvider!

    public init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, registrar: FlutterPluginRegistrar) {
        let channelName = String(format: "plugins.indoor.solutions/opentok_%lld", viewId)

        self.frame = frame
        self.registrar = registrar
        self.viewId = viewId

        channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())

        openTokView = UIView(frame: self.frame)
        openTokView.isOpaque = true
        
        if let arguments = args as? [String: Any],
            let width = arguments["width"] as? Int,
            let height = arguments["height"] as? Int {
            screenHeight = height
            screenWidth = width
            
            
        }
        
        if let arguments = args as? [String: Any],
            let pubWidth = arguments["publisherWidth"] as? Int,
            let pubHeight = arguments["publisherHeight"] as? Int {
            publisherWidth = pubWidth
            publisherHeight = pubHeight
        }

        // Decode publisher settings.
        if let arguments = args as? [String: Any],
            let publisherArg = arguments["publisherSettings"] as? String {
            do {
                let jsonDecoder = JSONDecoder()

                publisherSettings = try jsonDecoder.decode(PublisherSettings.self, from: publisherArg.data(using: .utf8)!)
            } catch {
                if SwiftFlutterOpentokPlugin.loggingEnabled {
                    print("OpenTok publisher settings error: \(error.localizedDescription)")
                }
            }
        }

        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("[FlutterOpenTokViewController] initialized with size: \(screenWidth ?? 100) (w) x \(screenHeight ?? 100) (h)")
        }

        super.init()
    }

    deinit {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("[DEINIT] FlutterOpenTokViewController")
        }
    }

    /// Where the magic happens.
    public func view() -> UIView {
        return openTokView
    }

    fileprivate func configureAudioSession() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("[FlutterOpenTokViewController] Configure audio session")
            print("[FlutterOpenTokViewController] Switched to speaker = \(switchedToSpeaker)")
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetooth])
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("[FlutterOpenTokViewController] Session setCategory error: \(error)")
            }
        }

        do {
            try AVAudioSession.sharedInstance().setMode(switchedToSpeaker ? AVAudioSession.Mode.videoChat : AVAudioSession.Mode.voiceChat)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("[FlutterOpenTokViewController] Session setMode error: \(error)")
            }
        }

        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(switchedToSpeaker ? .speaker : .none)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("[FlutterOpenTokViewController] Session overrideOutputAudioPort error: \(error)")
            }
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("[FlutterOpenTokViewController] Session setActive error: \(error)")
            }
        }
    }

    fileprivate func closeAudioSession() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("[FlutterOpenTokViewController] Close audio session")
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("[FlutterOpenTokViewController] Session setActive error: \(error)")
            }
        }
    }

    var subscriperView: UIView? {
        if let openTokProvider = self.provider as? OpenTokVoIPImpl {
            return openTokProvider.subscriberView
        }
        return nil
    }
    
    var publisherView: UIView? {
        if let openTokProvider = self.provider as? OpenTokVoIPImpl {
            return openTokProvider.publisherView
        }
        return nil
    }

    /**
     Create an instance of VoIPProvider. This is what implements VoIP
     for the application.
     */
    private func createProvider() {
        provider = OpenTokVoIPImpl(delegate: self, publisherSettings: publisherSettings)
    }
}

extension FlutterOpenTokViewController: FlutterViewControllerImpl {
    func setup() {
        // Create VoIP provider
        createProvider()

        // Listen for method calls from Dart.
        channel.setMethodCallHandler {
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self?.onMethodCall(call: call, result: result)
        }
    }

    func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "create" {
            guard let args = call.arguments else {
                return
            }

            if let methodArgs = args as? [String: Any],
                let apiKey = methodArgs["apiKey"] as? String,
                let sessionId = methodArgs["sessionId"] as? String,
                let token = methodArgs["token"] as? String {
                provider?.connect(apiKey: apiKey, sessionId: sessionId, token: token)
                result(nil)
            } else {
                result("iOS could not extract flutter arguments in method: (create)")
            }
        } else if call.method == "destroy" {
            provider?.disconnect()
            result(nil)
        } else if call.method == "enablePublisherVideo" {
            provider?.enablePublisherVideo()
            refreshViews()
            result(nil)
        } else if call.method == "disablePublisherVideo" {
            provider?.disablePublisherVideo()
            refreshViews()
            result(nil)
        } else if call.method == "unmutePublisherAudio" {
            provider?.unmutePublisherAudio()
            result(nil)
        } else if call.method == "mutePublisherAudio" {
            provider?.mutePublisherAudio()
            result(nil)
        } else if call.method == "muteSubscriberAudio" {
            provider?.muteSubscriberAudio()
            result(nil)
        } else if call.method == "unmuteSubscriberAudio" {
            provider?.unmuteSubscriberAudio()
            result(nil)
        } else if call.method == "switchAudioToSpeaker" {
            switchedToSpeaker = true
            configureAudioSession()
            result(nil)
        } else if call.method == "switchAudioToReceiver" {
            switchedToSpeaker = false
            configureAudioSession()
            result(nil)
        } else if call.method == "switchCamera" {
            provider.switchCamera()
            result(nil)
        }
        else if call.method == "getSdkVersion" {
            result(OPENTOK_LIBRARY_VERSION)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    func channelInvokeMethod(_ method: String, arguments: Any?) {
        channel.invokeMethod(method, arguments: arguments) {
            (result: Any?) -> Void in
            if let error = result as? FlutterError {
                if SwiftFlutterOpentokPlugin.loggingEnabled {
                    if #available(iOS 10.0, *) {
                        os_log("%@ failed: %@", type: .error, method, error.message!)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            } else if FlutterMethodNotImplemented.isEqual(result) {
                if SwiftFlutterOpentokPlugin.loggingEnabled {
                    if #available(iOS 10.0, *) {
                        os_log("%@ not implemented", type: .error)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        }
    }
}

extension FlutterOpenTokViewController: VoIPProviderDelegate {
    func didCreateStream() {
        channelInvokeMethod("onCreateStream", arguments: nil)
    }

    func didDropStream() {
        channelInvokeMethod("onDroppedStream", arguments: nil)
    }

    func didCreatePublisherStream() {
        channelInvokeMethod("onCreatePublisherStream", arguments: nil)
    }

    func willConnect() {
        channelInvokeMethod("onWillConnect", arguments: nil)
    }

    func didConnect() {
        configureAudioSession()
        refreshViews()
        channelInvokeMethod("onSessionConnect", arguments: nil)
    }

    func didDisconnect() {
        closeAudioSession()

        channelInvokeMethod("onSessionDisconnect", arguments: nil)
    }

    func didReceiveVideo() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("[FlutterOpenTokViewController] Receive video")
        }
        refreshViews()
        channelInvokeMethod("onReceiveVideo", arguments: nil)
    }
    
    func refreshViews() {
        if (openTokView.subviews.count > 0) {
            for subView in openTokView.subviews as [UIView] {
                subView.removeFromSuperview()
            }
        }
        
        if let view = self.subscriperView {
            openTokView.addSubview(view)

            view.backgroundColor = .black
            view.snp.makeConstraints { (make) -> Void in
                make.top.equalTo(openTokView)
                make.left.equalTo(openTokView)
                make.bottom.equalTo(openTokView)
                make.right.equalTo(openTokView)
            }
        }
        
        if provider.isAudioOnly == false {
            if let view = self.publisherView {
                openTokView.addSubview(view)
                
                view.backgroundColor = .black
                view.frame = CGRect(x: 0, y: 0, width: publisherWidth, height: publisherHeight)
                view.isUserInteractionEnabled = true
                let pan = UIPanGestureRecognizer(target: self, action: #selector(panView))
                view.addGestureRecognizer(pan)
            }
        }
    }
    
    @objc func panView(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self.openTokView)

        if let viewToDrag = sender.view {
            let halfWidth = viewToDrag.frame.width / 2
            let halfHeight = viewToDrag.frame.height / 2
            
            var x = viewToDrag.center.x + translation.x
            if (x < halfWidth) {
              x = halfWidth
            }
            if (x > self.openTokView.frame.width - halfWidth ) {
              x = self.openTokView.frame.width - halfWidth
            }
            
            var y = viewToDrag.center.y + translation.y
            if (y < halfHeight) {
              y = halfHeight
            }
            if (y > self.openTokView.frame.height - halfHeight ) {
              y = self.openTokView.frame.height - halfHeight
            }
            viewToDrag.center = CGPoint(x: x, y: y)
            sender.setTranslation(CGPoint(x: 0, y: 0), in: viewToDrag)
        }
    }
}

enum OTCameraCaptureResolution: String, Codable {
    case OTCameraCaptureResolutionLow,
         OTCameraCaptureResolutionMedium,
         OTCameraCaptureResolutionHigh
}

enum OTCameraCaptureFrameRate: String, Codable {
  case OTCameraCaptureFrameRate30FPS,
    OTCameraCaptureFrameRate15FPS,
    OTCameraCaptureFrameRate7FPS,
    OTCameraCaptureFrameRate1FPS
}

struct PublisherSettings: Codable {
    var name: String?
    var audioTrack: Bool?
    var videoTrack: Bool?
    var audioBitrate: Int?
    var cameraResolution: OTCameraCaptureResolution?
    var cameraFrameRate: OTCameraCaptureFrameRate?
}
