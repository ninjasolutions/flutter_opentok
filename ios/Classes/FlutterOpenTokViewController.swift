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
        
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("FlutterOpenTokViewController initialized with size: \(screenWidth ?? 100) (w) x \(screenHeight ?? 100) (h)")
        }
        
        super.init()
    }
    
    deinit {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("[DEINIT] FlutterOpenTokViewController")
        }
    }
    
    /// Where the magic happens.
    public func view() -> UIView {
        return openTokView
    }
    
    fileprivate func configureAudioSession() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Configure audio session")
            print("Switched to speaker = \(switchedToSpeaker)")
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.mixWithOthers, .allowBluetooth])
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
               print("Session setCategory error: \(error)")
            }
        }
        
        do {
            try AVAudioSession.sharedInstance().setMode(self.switchedToSpeaker ? AVAudioSessionModeVideoChat : AVAudioSessionModeVoiceChat)
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Session setMode error: \(error)")
            }
        }
        
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(self.switchedToSpeaker ? .speaker : .none)
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Session overrideOutputAudioPort error: \(error)")
            }
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Session setActive error: \(error)")
            }
        }
    }

    
    fileprivate func closeAudioSession() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Close audio session")
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
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
        self.provider = OpenTokVoIPImpl(delegate: self)
    }
    
}

extension FlutterOpenTokViewController: FlutterViewControllerImpl {
    func setup() {
        // Create VoIP provider
        self.createProvider()
        
        // Listen for method calls from Dart.
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
                self.provider?.connect(apiKey: apiKey, sessionId: sessionId, token: token)
                
                // Enable audio if possible.
                if let enablePublisherVideo = methodArgs["enablePublishVideo"] as? Bool {
                    self.enablePublisherVideo = enablePublisherVideo
                }
                
                result(nil);
            } else {
                result("iOS could not extract flutter arguments in method: (create)")
            }
        } else if call.method == "destroy" {
            self.provider?.disconnect()
            result(nil)
        } else if call.method == "enablePublisherVideo" {
            self.provider?.enablePublisherVideo()
            result(nil)
        } else if call.method == "disablePublisherVideo" {
            self.provider?.disablePublisherVideo()
            result(nil)
        } else if call.method == "enablePublisherAudio" {
            self.provider?.unmutePublisherAudio()
            result(nil)
        } else if call.method == "disablePublisherAudio" {
            self.provider?.mutePublisherAudio()
            result(nil)
        } else if call.method == "switchAudioToSpeaker" {
            self.switchAudioSessionToSpeaker()
            result(nil)
        } else if call.method == "switchAudioToReceiver" {
            self.switchAudioSessionToReceiver()
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
                if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                    if #available(iOS 10.0, *) {
                        os_log("%@ failed: %@", type: .error, method, error.message!)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            } else if FlutterMethodNotImplemented.isEqual(result) {
                if SwiftFlutterOpentokPlugin.isLoggingEnabled {
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
    
    func willConnect() {
        self.configureAudioSession()
        
        if let enablePublisherVideo = self.enablePublisherVideo {
            if enablePublisherVideo == true {
                let videoPermission = AVCaptureDevice.authorizationStatus(for: .video)
                let videoEnabled = (videoPermission == .authorized)
                
                self.provider?.isAudioOnly = !videoEnabled
            }
        }
    }
    
    func didConnect() {
    }
    
    func didDisconnect() {
        self.closeAudioSession()
    }
    
    func didReceiveVideo() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Receive video")
        }
        
        if let view = self.videoView {
            view.frame = CGRect(
                x: 0,
                y: 0,
                width: self.openTokView.frame.width,
                height: self.openTokView.frame.height
            )
            
            openTokView.addSubview(view)
        }
    }
    
}


extension FlutterOpenTokViewController {
    
    func switchAudioSessionToSpeaker() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print(#function)
        }
        
        do {
            try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeVideoChat)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
            self.switchedToSpeaker = true
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Session overrideOutputAudioPort error: \(error)")
            }
        }
    }
    
    func switchAudioSessionToReceiver() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print(#function)
        }
        
        do {
            try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeVoiceChat)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSessionPortOverride.none)
            self.switchedToSpeaker = false
        } catch {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Session overrideOutputAudioPort error: \(error)")
            }
        }
    }
    
}
