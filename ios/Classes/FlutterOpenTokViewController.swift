//
//  FlutterOpenTokView.swift
//  flutter_opentok
//
//  Created by Genert Org on 22/08/2019.
//

import Foundation
import OpenTok
import SnapKit
import os

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
        openTokView.isOpaque = false
        openTokView.backgroundColor = UIColor.black

        if let arguments = args as? [String: Any],
            let width = arguments["width"] as? Int,
            let height = arguments["height"] as? Int {
            screenHeight = height
            screenWidth = width
        }

        // Decode publisher settings.
        if let arguments = args as? [String: Any],
            let publisherArg = arguments["publisherSettings"] as? String {
            do {
                let jsonDecoder = JSONDecoder()

                self.publisherSettings = try jsonDecoder.decode(PublisherSettings.self, from: publisherArg.data(using: .utf8)!)
            } catch {
                if SwiftFlutterOpentokPlugin.loggingEnabled {
                    print("OpenTok publisher settings error: \(error.localizedDescription)")
                }
            }
        }

        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("FlutterOpenTokViewController initialized with size: \(screenWidth ?? 100) (w) x \(screenHeight ?? 100) (h)")
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
            print("Configure audio session")
            print("Switched to speaker = \(switchedToSpeaker)")
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetooth])
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session setCategory error: \(error)")
            }
        }

        do {
            try AVAudioSession.sharedInstance().setMode(switchedToSpeaker ? AVAudioSession.Mode.videoChat : AVAudioSession.Mode.voiceChat)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session setMode error: \(error)")
            }
        }

        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(switchedToSpeaker ? .speaker : .none)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session overrideOutputAudioPort error: \(error)")
            }
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session setActive error: \(error)")
            }
        }
    }

    fileprivate func closeAudioSession() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Close audio session")
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session setActive error: \(error)")
            }
        }
    }

    /// Convenience getter for current video view based on provider implementation
    var videoView: UIView? {
        if let openTokProvider = self.provider as? OpenTokVoIPImpl {
            return openTokProvider.subscriberView
        }
        return nil
    }

    /**
     Create an instance of VoIPProvider. This is what implements VoIP
     for the application.
     */
    private func createProvider() {
        provider = OpenTokVoIPImpl(delegate: self, publisherSettings: self.publisherSettings)
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
            result(nil)
        } else if call.method == "disablePublisherVideo" {
            provider?.disablePublisherVideo()
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
            switchAudioSessionToSpeaker()
            result(nil)
        } else if call.method == "switchAudioToReceiver" {
            switchAudioSessionToReceiver()
            result(nil)
        } else if call.method == "getSdkVersion" {
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
    
    func didCreatePublisherStream() {
        channelInvokeMethod("onCreatePublisherStream", arguments: nil)
    }
    
    func willConnect() {
        configureAudioSession()
        
        channelInvokeMethod("onWillConnect", arguments: nil)
        
        if let enablePublisherVideo = self.enablePublisherVideo {
            if enablePublisherVideo == true {
                let videoPermission = AVCaptureDevice.authorizationStatus(for: .video)
                let videoEnabled = (videoPermission == .authorized)

                provider?.isAudioOnly = !videoEnabled
            }
        }
    }

    func didConnect() {
        channelInvokeMethod("onSessionConnect", arguments: nil)
    }

    func didDisconnect() {
        closeAudioSession()
        
        channelInvokeMethod("onSessionDisconnect", arguments: nil)
    }

    func didReceiveVideo() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Receive video")
        }
        
        channelInvokeMethod("onReceiveVideo", arguments: nil)

        if let view = self.videoView {
            channelInvokeMethod("onReceiveVideo", arguments: nil)

            openTokView.addSubview(view)
            
            view.backgroundColor = .black
            view.snp.makeConstraints { (make) -> Void in
                make.top.equalTo(openTokView)
                make.left.equalTo(openTokView)
                make.bottom.equalTo(openTokView)
                make.right.equalTo(openTokView)
            }
        }
    }
}

extension FlutterOpenTokViewController {
    func switchAudioSessionToSpeaker() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print(#function)
        }

        do {
            try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.videoChat)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            switchedToSpeaker = true
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session overrideOutputAudioPort error: \(error)")
            }
        }
    }

    func switchAudioSessionToReceiver() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print(#function)
        }

        do {
            try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            switchedToSpeaker = false
        } catch {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Session overrideOutputAudioPort error: \(error)")
            }
        }
    }
}

struct PublisherSettings: Codable {
    var name: String?
    var audioTrack: Bool?
    var videoTrack: Bool?
    var audioBitrate: Int?
}
