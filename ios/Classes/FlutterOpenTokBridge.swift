//
//  FlutterOpenTokBridge.swift
//  flutter_opentok
//
//  Created by Genert Org on 21/08/2019.
//

import UIKit
import OpenTok

public class FlutterOpenTokBridge: UIViewController {
    var session: OTSession?
    
    var publisher: OTPublisher?
    
    var subscriber: OTSubscriber?
    
    func create(apiKey: String, sessionId: String, token: String) {
        session = OTSession(apiKey: apiKey, sessionId: sessionId, delegate: self)!
        
        doConnect(token);
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
}

// OTSession delegate callbacks
extension FlutterOpenTokBridge: OTSessionDelegate {
    public func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
    }
    
    public func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    public func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
    }
    
    public func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
    }
    
    public func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
}

// OTPublisher delegate callbacks
extension FlutterOpenTokBridge: OTPublisherDelegate {
    public func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    }
    
    public func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
    }
    
    public func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// OTSubscriberDelegate callbacks
extension FlutterOpenTokBridge: OTSubscriberDelegate {
    public func subscriberDidConnect(toStream subscriber: OTSubscriberKit) {
        print("The subscriber did connect to the stream.")
    }
    
    public func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("The subscriber failed to connect to the stream.")
    }
}
