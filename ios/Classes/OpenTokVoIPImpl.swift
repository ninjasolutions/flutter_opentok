//
//  OpenTokVoIPImpl.swift
//  flutter_opentok
//
//  Created by Genert Org on 18/09/2019.
//

import Foundation
import OpenTok
import os.log

protocol VoIPProviderDelegate {
    func willConnect()
    func didConnect()
    func didDisconnect()
    func didReceiveVideo()
    func didCreateStream()
    func didDropStream()
    func didCreatePublisherStream()
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
            os_log("[DEINIT] OpenTokVoIPImpl", type: .info)
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
            os_log("[OpenTokVoIPImpl] Enable publisher audio", type: .info)
        }

        if publisher != nil {
            publisher.publishAudio = false
        }
    }

    func unmutePublisherAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Unmute publisher audio", type: .info)
        }

        if publisher != nil {
            publisher.publishAudio = true
        }
    }

    func muteSubscriberAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Mute subscriber audio", type: .info)
        }

        if subscriber != nil {
            subscriber.subscribeToAudio = false
        }
    }

    func unmuteSubscriberAudio() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Unmute subscriber audio", type: .info)
        }

        if subscriber != nil {
            subscriber.subscribeToAudio = true
        }
    }

    func enablePublisherVideo() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Enable publisher video", type: .info)
        }

        if publisher != nil {
            let videoPermission = AVCaptureDevice.authorizationStatus(for: .video)
            let videoEnabled = (videoPermission == .authorized)

            publisher.publishVideo = videoEnabled
        }
    }

    func disablePublisherVideo() {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Disable publisher video", type: .info)
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
            os_log("[OpenTokVoIPImpl] Create OTSession", type: .info)
            os_log("[OpenTokVoIPImpl] API key: %s", type: .info, key)
            os_log("[OpenTokVoIPImpl] Session ID: %s", type: .info, sessionId)
            os_log("[OpenTokVoIPImpl] Token: %s", type: .info, token)
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
            os_log("[OpenTokVoIPImpl] Publish", type: .info)
        }

        let settings = OTPublisherSettings()

        settings.name = publisherSettings?.name ?? UIDevice.current.name
        settings.videoTrack = publisherSettings?.videoTrack ?? true
        settings.audioTrack = publisherSettings?.audioTrack ?? true
        settings.cameraResolution = .high
        settings.cameraFrameRate = .rate30FPS

        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Settings: %@", type: .info, settings.description)
        }

        publisher = OTPublisher(delegate: self, settings: settings)
        publisher.cameraPosition = .front
        publisher.publishVideo = false

        // Publish publisher to session
        var error: OTError?

        session.publish(publisher, error: &error)

        guard error == nil else {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                os_log("[OpenTokVoIPImpl] %s", type: .info, error.debugDescription)
            }
            return
        }
    }

    func unpublish() {
        if publisher != nil {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                os_log("[OpenTokVoIPImpl] Unpublish")
            }

            session.unpublish(publisher, error: nil)
            publisher = nil
        }
    }

    func subscribe(toStream stream: OTStream) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OpenTokVoIPImpl] Subscribe to stream %s", type: .info, stream.name ?? "<No stream name>")
        }

        subscriber = OTSubscriber(stream: stream, delegate: self)

        session.subscribe(subscriber, error: nil)
    }

    func unsubscribe() {
        if subscriber != nil {
            if SwiftFlutterOpentokPlugin.loggingEnabled {
                os_log("[OpenTokVoIPImpl] Unsubscribe")
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
                os_log("[OTSubscriberDelegate] %s", type: .info, e.localizedDescription)
            }
        }
    }
}

extension OpenTokVoIPImpl: OTSessionDelegate {
    public func sessionDidConnect(_: OTSession) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)
        publish()
        delegate?.didConnect()
    }

    public func sessionDidReconnect(_: OTSession) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)
    }

    public func sessionDidDisconnect(_: OTSession) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)

        unsubscribe()
        unpublish()

        if session != nil {
            session = nil
        }

        videoReceived = false

        delegate?.didDisconnect()
    }

    public func sessionDidBeginReconnecting(_: OTSession) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)
    }

    public func session(_: OTSession, didFailWithError error: OTError) {
        os_log("[OTSubscriberDelegate] %s %s", type: .info, #function, error)
    }

    public func session(_: OTSession, streamCreated stream: OTStream) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)

        subscribe(toStream: stream)

        delegate?.didCreateStream()
    }

    public func session(_: OTSession, streamDestroyed stream: OTStream) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)

        delegate?.didDropStream()
    }

    public func session(_: OTSession, connectionCreated connection: OTConnection) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)
    }

    public func session(_: OTSession, connectionDestroyed connection: OTConnection) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)

        disconnectSession()
    }

    public func session(_: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        os_log("[OTSubscriberDelegate] %s %s %s %s", type: .info, #function, type ?? "<No signal type>", connection ?? "<Nil connection>", string ?? "<No string>")
    }
}

extension OpenTokVoIPImpl: OTPublisherDelegate {
    public func publisher(_: OTPublisherKit, streamCreated stream: OTStream) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)

        delegate?.didCreatePublisherStream()
    }

    public func publisher(_: OTPublisherKit, streamDestroyed stream: OTStream) {
        os_log("[OTSubscriberDelegate] %s", type: .info, #function)

        unpublish()
    }

    public func publisher(_: OTPublisherKit, didFailWithError error: OTError) {
        os_log("[OTSubscriberDelegate] %s %s", type: .info, #function, error.description)
    }

    public func publisher(_: OTPublisher, didChangeCameraPosition position: AVCaptureDevice.Position) {
        os_log("[OTSubscriberDelegate] %s %d", type: .info, #function, position.rawValue)
    }
}

extension OpenTokVoIPImpl: OTSubscriberDelegate {
    public func subscriberDidConnect(toStream _: OTSubscriberKit) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] %@", type: .info, #function)
        }
    }

    public func subscriberDidReconnect(toStream _: OTSubscriberKit) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] %@", type: .info, #function)
        }
    }

    public func subscriberDidDisconnect(fromStream _: OTSubscriberKit) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] %@", type: .info, #function)
        }

        unsubscribe()
        delegate?.didDropStream()
    }

    public func subscriber(_: OTSubscriberKit, didFailWithError error: OTError) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] subscriber %@", type: .info, error)
        }
    }

    public func subscriberVideoEnabled(_: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] subscriberVideoEnabled %d", type: .info, reason.rawValue)
        }
    }

    public func subscriberVideoDisabled(_: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] subscriberVideoDisabled %d", type: .info, reason.rawValue)
        }
    }

    public func subscriberVideoDataReceived(_: OTSubscriber) {
        if SwiftFlutterOpentokPlugin.loggingEnabled {
            os_log("[OTSubscriberDelegate] subscriberVideoDataReceived", type: .info)
        }

        if videoReceived == false {
            videoReceived = true
            delegate?.didReceiveVideo()
        }
    }
}
