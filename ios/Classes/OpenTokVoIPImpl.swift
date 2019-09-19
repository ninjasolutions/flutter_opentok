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
    
    func muteSubscriberAudio()
    func unmuteSubscriberAudio()

    func enablePublisherVideo()
    func disablePublisherVideo()
}

class OpenTokVoIPImpl: NSObject {
    var delegate: VoIPProviderDelegate?
    var publisherSettings: PublisherSettings?

    var subscriberView: UIView? {
        return subscriber?.view
    }

    init(delegate: VoIPProviderDelegate?, publisherSettings: PublisherSettings?) {
        super.init()
        self.delegate = delegate
        self.publisherSettings = publisherSettings
    }

    // MARK: - Private

    fileprivate var session: OTSession!
    fileprivate var publisher: OTPublisher!
    fileprivate var subscriber: OTSubscriber!
    fileprivate var videoReceived: Bool = false

    private var publishVideo: Bool = false {
        didSet {
            publisher?.publishVideo = publishVideo
        }
    }

    deinit {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("[DEINIT] OpenTokVoIPImpl")
        }
    }
}

extension OpenTokVoIPImpl: VoIPProvider {
    
    var isConnected: Bool {
        return session?.connection != nil
    }

    func connect(apiKey: String, sessionId: String, token: String) {
        delegate?.willConnect()

        createSession(key: apiKey, sessionId: sessionId, token: token)
    }

    func disconnect() {
        disconnectSession()
    }

    func mutePublisherAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Enable publisher audio")
        }

        if publisher != nil {
            publisher.publishAudio = false
        }
    }

    func unmutePublisherAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Unmute publisher audio")
        }

        if publisher != nil {
            publisher.publishAudio = true
        }
    }
    
    func muteSubscriberAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Mute subscriber audio")
        }
        
        if subscriber != nil {
            subscriber.subscribeToAudio = false
        }
    }
    
    func unmuteSubscriberAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Unmute subscriber audio")
        }
        
        if subscriber != nil {
            subscriber.subscribeToAudio = true
        }
    }

    func enablePublisherVideo() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Enable publisher video")
        }

        if publisher != nil {
            let videoPermission = AVCaptureDevice.authorizationStatus(for: .video)
            let videoEnabled = (videoPermission == .authorized)
            
            publisher.publishVideo = videoEnabled
        }
    }

    func disablePublisherVideo() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Disable publisher video")
        }

        if publisher != nil {
            publisher.publishVideo = false
        }
    }

    var isMuted: Bool {
        get { return !(publisher?.publishAudio ?? false) }
        set { publisher?.publishAudio = !newValue }
    }

    var isAudioOnly: Bool {
        get { return !publishVideo }
        set { publishVideo = !newValue }
    }
}

private extension OpenTokVoIPImpl {
    func createSession(key: String, sessionId: String, token: String) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Create OTSession")
            print("API key: \(key)")
            print("Session ID: \(sessionId)")
            print("Token: \(token)")
        }

        if key == "" || sessionId == "" || token == "" {
            return
        }

        session = OTSession(apiKey: key, sessionId: sessionId, delegate: self)

        doConnect(token)
    }

    func disconnectSession() {
        if session != nil {
            session.disconnect(nil)
        }
    }

    func publish() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Publish")
        }

        let settings = OTPublisherSettings()

        settings.name = self.publisherSettings?.name ?? UIDevice.current.name
        settings.videoTrack = self.publisherSettings?.videoTrack ?? true
        settings.audioTrack = self.publisherSettings?.audioTrack ?? true
        settings.cameraResolution = .high
        settings.cameraFrameRate = .rate30FPS
        
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print(settings)
        }

        publisher = OTPublisher(delegate: self, settings: settings)
        publisher.cameraPosition = .front

        // Publish publisher to session
        var error: OTError?

        session.publish(publisher, error: &error)

        guard error == nil else {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print(error.debugDescription)
            }
            return
        }
    }

    func unpublish() {
        if publisher != nil {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Unpublish")
            }

            session.unpublish(publisher, error: nil)
            publisher = nil
        }
    }

    func subscribe(toStream stream: OTStream) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            print("Subscribe to stream \(stream.name ?? "<No stream name>")")
        }

        subscriber = OTSubscriber(stream: stream, delegate: self)

        session.subscribe(subscriber, error: nil)
    }

    func unsubscribe() {
        if subscriber != nil {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print("Unsubscribe")
            }

            session.unsubscribe(subscriber, error: nil)
            subscriber = nil
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
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                print(e.localizedDescription)
            }
        }
    }
}

extension OpenTokVoIPImpl: OTSessionDelegate {
    public func sessionDidConnect(_: OTSession) {
        print(#function)
        publish()
        delegate?.didConnect()
    }

    public func sessionDidReconnect(_: OTSession) {
        print(#function)
    }

    public func sessionDidDisconnect(_: OTSession) {
        print(#function)

        unsubscribe()
        unpublish()

        if session != nil {
            session = nil
        }

        videoReceived = false

        delegate?.didDisconnect()
    }

    public func sessionDidBeginReconnecting(_: OTSession) {
        print(#function)
    }

    public func session(_: OTSession, didFailWithError error: OTError) {
        print(#function, error)
    }

    public func session(_: OTSession, streamCreated stream: OTStream) {
        print(#function, stream)

        subscribe(toStream: stream)
    }

    public func session(_: OTSession, streamDestroyed stream: OTStream) {
        print(#function, stream)
    }

    public func session(_: OTSession, connectionCreated connection: OTConnection) {
        print(#function, connection)
    }

    public func session(_: OTSession, connectionDestroyed connection: OTConnection) {
        print(#function, connection)

        disconnectSession()
    }

    public func session(_: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        print(#function, type ?? "<No signal type>", connection ?? "<Nil connection>", string ?? "<No string>")
    }
}

extension OpenTokVoIPImpl: OTPublisherDelegate {
    public func publisher(_: OTPublisherKit, streamCreated stream: OTStream) {
        print(#function, stream)
    }

    public func publisher(_: OTPublisherKit, streamDestroyed stream: OTStream) {
        print(#function, stream)

        unpublish()
    }

    public func publisher(_: OTPublisherKit, didFailWithError error: OTError) {
        print(#function, error)
    }

    public func publisher(_: OTPublisher, didChangeCameraPosition position: AVCaptureDevice.Position) {
        print(#function, position)
    }
}

extension OpenTokVoIPImpl: OTSubscriberDelegate {
    public func subscriberDidConnect(toStream _: OTSubscriberKit) {
        print(#function)
    }

    public func subscriberDidReconnect(toStream _: OTSubscriberKit) {
        print(#function)
    }

    public func subscriberDidDisconnect(fromStream _: OTSubscriberKit) {
        print(#function)

        unsubscribe()
    }

    public func subscriber(_: OTSubscriberKit, didFailWithError error: OTError) {
        print(#function, error)
    }

    public func subscriberVideoEnabled(_: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        print(#function, reason)
    }

    public func subscriberVideoDisabled(_: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        print(#function, reason)
    }

    public func subscriberVideoDataReceived(_: OTSubscriber) {
        if videoReceived == false {
            videoReceived = true
            delegate?.didReceiveVideo()
        }
    }
}
