//
//  OpenTokVoIPImpl.swift
//  flutter_opentok
//
//  Created by Genert Org on 18/09/2019.
//

import Foundation
import OpenTok

protocol VoIPProviderDelegate {
    func willConnect()
    func didConnect()
    func didDisconnect()
    func didReceiveVideo()
}

public protocol VoIPProvider {
    
    /// Whether VoIP connection has been established.
    var isConnected: Bool { get }
    
    // Set whether publisher has audio or not.
    var isAudioOnly: Bool { get set }
    
    func connect(apiKey: String, sessionId: String, token: String)
    func disconnect()
    
    func mutePublisherAudio()
    func unmutePublisherAudio()
    
    func enablePublisherVideo()
    func disablePublisherVideo()
}


class OpenTokVoIPImpl: NSObject {
    
    var delegate: VoIPProviderDelegate?
    
    var subscriberView: UIView? {
        return self.subscriber?.view
    }
    
    init(delegate: VoIPProviderDelegate?) {
        super.init()
        self.delegate = delegate
    }
    
    // MARK: - Private
    
    fileprivate var session: OTSession!
    fileprivate var publisher: OTPublisher!
    fileprivate var subscriber: OTSubscriber!
    fileprivate var videoReceived: Bool = false
    
    private var publishVideo: Bool = false {
        didSet {
            publisher?.publishVideo = self.publishVideo
        }
    }
    
    deinit {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("[DEINIT] OpenTokVoIPImpl")
        }
    }
}

extension OpenTokVoIPImpl: VoIPProvider {

    var isConnected: Bool {
        return self.session?.connection != nil
    }
    
    func connect(apiKey: String, sessionId: String, token: String) {
        self.delegate?.willConnect()
        
        self.createSession(key: apiKey, sessionId: sessionId, token: token)
    }
    
    func disconnect() {
        self.disconnectSession()
    }
    
    func mutePublisherAudio() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Enable publisher audio")
        }
        
        if self.publisher != nil {
            self.publisher.publishAudio = false
        }
    }
    
    func unmutePublisherAudio() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Unmute publisher audio")
        }
        
        if self.publisher != nil {
            self.publisher.publishAudio = true
        }
    }
    
    func enablePublisherVideo() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Enable publisher video")
        }
        
        if self.publisher != nil {
            let videoPermission = AVCaptureDevice.authorizationStatus(for: .video)
            let videoEnabled = (videoPermission == .authorized)
            
            self.isAudioOnly = !videoEnabled
        }
    }

    func disablePublisherVideo() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Disable publisher video")
        }
        
        if self.publisher != nil {
            self.isAudioOnly = true
        }
    }
    
    var isMuted: Bool {
        get { return !(self.publisher?.publishAudio ?? false) }
        set { self.publisher?.publishAudio = !newValue }
    }
    
    var isAudioOnly: Bool {
        get { return !self.publishVideo }
        set { self.publishVideo = !newValue }
    }
}

private extension OpenTokVoIPImpl {
    
    func createSession(key: String, sessionId: String, token: String) {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Create OTSession")
            print("API key: \(key)")
            print("Session ID: \(sessionId)")
            print("Token: \(token)")
        }
        
        if key == "" || sessionId == "" || token == "" {
            return
        }
        
        self.session = OTSession(apiKey: key, sessionId: sessionId, delegate: self)

        self.doConnect(token)
    }
    
    func disconnectSession() {
        if self.session != nil {
            self.session.disconnect(nil)
        }
    }
    
    func publish() {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Publish")
        }
        
        let settings = OTPublisherSettings()
        
        settings.name = UIDevice.current.name
        settings.videoTrack = true
        settings.audioTrack = true
        
        self.publisher = OTPublisher(delegate: self, settings: settings)
        self.publisher.cameraPosition = .front
        
        // Publish publisher to session
        var error: OTError?
        
        self.session.publish(self.publisher, error: &error)
        
        guard error == nil else {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print(error.debugDescription)
            }
            return
        }
    }
    
    func unpublish() {
        if self.publisher != nil {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Unpublish")
            }
            
            self.session.unpublish(self.publisher, error: nil)
            self.publisher = nil
        }
    }
    
    func subscribe(toStream stream: OTStream) {
        if SwiftFlutterOpentokPlugin.isLoggingEnabled {
            print("Subscribe to stream \(stream.name ?? "<No stream name>")")
        }
        
        self.subscriber = OTSubscriber(stream: stream, delegate: self)
        
        self.session.subscribe(self.subscriber, error: nil)
    }
    
    func unsubscribe() {
        if self.subscriber != nil {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print("Unsubscribe")
            }
            
            self.session.unsubscribe(self.subscriber, error: nil)
            self.subscriber = nil
        }
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
    
    private func process(error err: OTError?) {
        if let e = err {
            if SwiftFlutterOpentokPlugin.isLoggingEnabled {
                print(e.localizedDescription)
            }
        }
    }
    
}

extension OpenTokVoIPImpl: OTSessionDelegate {
    
    public func sessionDidConnect(_ session: OTSession) {
        print(#function)
        self.publish()
        self.delegate?.didConnect()
    }
    
    public func sessionDidReconnect(_ session: OTSession) {
        print(#function)
    }
    
    public func sessionDidDisconnect(_ session: OTSession) {
        print(#function)
        
        self.unsubscribe()
        self.unpublish()
        
        if self.session != nil {
            self.session = nil
        }
        
        self.videoReceived = false
        
        self.delegate?.didDisconnect()
    }
    
    public func sessionDidBeginReconnecting(_ session: OTSession) {
        print(#function)
    }
    
    public func session(_ session: OTSession, didFailWithError error: OTError) {
        print(#function, error)
    }
    
    public func session(_ session: OTSession, streamCreated stream: OTStream) {
        print(#function, stream)
        
        self.subscribe(toStream: stream)
    }
    
    public func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print(#function, stream)
    }
    
    public func session(_ session: OTSession, connectionCreated connection: OTConnection) {
        print(#function, connection)
    }
    
    public func session(_ session: OTSession, connectionDestroyed connection: OTConnection) {
        print(#function, connection)
        
        self.disconnectSession()
    }
    
    public func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        print(#function, type ?? "<No signal type>", connection ?? "<Nil connection>", string ?? "<No string>")
    }
    
}


extension OpenTokVoIPImpl: OTPublisherDelegate {
    
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


extension OpenTokVoIPImpl: OTSubscriberDelegate {
    
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
    
    public func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
        if self.videoReceived == false {
            self.videoReceived = true
            self.delegate?.didReceiveVideo()
        }
    }
    
}

