package com.flutter_opentok

import android.content.Context
import android.view.View
import com.opentok.android.*

interface VoIPProviderDelegate {
    fun willConnect()
    fun didConnect()
    fun didDisconnect()
    fun didReceiveVideo()
    fun didCreateStream()
    fun didDropStream()
    fun didCreatePublisherStream()

    val context: Context
}


interface VoIPProvider {
    /// Whether VoIP connection has been established.
    val isConnected: Boolean

    // Set whether publisher has audio or not.
    var isAudioOnly: Boolean

    fun connect(apiKey: String, sessionId: String, token: String)
    fun disconnect()

    fun mutePublisherAudio()
    fun unmutePublisherAudio()

    fun muteSubscriberAudio()
    fun unmuteSubscriberAudio()

    fun enablePublisherVideo()
    fun disablePublisherVideo()

    fun switchCamera()
}

class OpenTokVoIPImpl(
        var delegate: VoIPProviderDelegate?,
        var publisherSettings: PublisherSettings?) : VoIPProvider, Session.SessionListener, PublisherKit.PublisherListener {

    private var session: Session? = null
    private var publisher: Publisher? = null
    private var subscriber: Subscriber? = null
    private var videoReceived: Boolean = false

    val subscriberView: View?
        get() {
            return subscriber?.view
        }

    val publisherView: View?
        get() {
            return publisher?.view
        }

    var publishVideo: Boolean
        get() {
            return publisher?.publishVideo!!
        }
        set(value) {
            publisher?.publishVideo = value
        }

    /// VoIPProvider

    override val isConnected: Boolean
        get() {
            return session?.connection != null
        }

    override var isAudioOnly: Boolean
        get() {
            return !publishVideo
        }
        set(value) {
            publishVideo = !value
        }

    override fun connect(apiKey: String, sessionId: String, token: String) {
        delegate?.willConnect()

        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[OpenTokVoIPImpl] Create OTSession")
            print("[OpenTokVoIPImpl] API key: $apiKey")
            print("[OpenTokVoIPImpl] Session ID: $sessionId")
            print("[OpenTokVoIPImpl] Token: $token")
        }

        if (apiKey == "" || sessionId == "" || token == "") {
            return
        }

        session = Session.Builder(delegate?.context, apiKey, sessionId).build()
        session?.setSessionListener(this)
        session?.connect(token)
    }

    override fun disconnect() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("Disconnecting from session")
        }

        session?.disconnect()
    }

    override fun mutePublisherAudio() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("Mute publisher audio")
        }

        publisher?.publishAudio = false
    }

    override fun unmutePublisherAudio() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("UnMute publisher audio")
        }

        publisher?.publishAudio = true
    }

    override fun muteSubscriberAudio() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("Mute subscriber audio")
        }

        subscriber?.subscribeToAudio = false
    }

    override fun unmuteSubscriberAudio() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("UnMute subscriber audio")
        }

        subscriber?.subscribeToAudio = true
    }

    override fun enablePublisherVideo() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("Enable publisher video")
        }

        publisher?.publishVideo = true
    }

    override fun disablePublisherVideo() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("Disable publisher video")
        }

        publisher?.publishVideo = false
    }

    override fun switchCamera() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("Switch Camera")
        }

        publisher?.cycleCamera()
    }

    /// SessionListener
    override fun onConnected(session: Session?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[SessionListener] onConnected")
        }
        publish()
        delegate?.didConnect()
    }

    override fun onDisconnected(session: Session?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[SessionListener] onDisconnected")
        }

        unsubscribe()
        unpublish()
        this.session = null
        videoReceived = false

        delegate?.didDisconnect()
    }

    override fun onStreamDropped(session: Session?, stream: Stream?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[SessionListener] onStreamDropped")
        }
        unsubscribe()
        delegate?.didDropStream()
    }

    override fun onStreamReceived(session: Session?, stream: Stream?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[SessionListener] onStreamReceived")
        }
        stream?.let { subscribe(it) }
        delegate?.didCreateStream()
        if (stream?.hasVideo() == true) {
            delegate?.didReceiveVideo()
        }
    }

    override fun onError(session: Session?, error: OpentokError?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[SessionListener] onError ${error?.message}")
        }
    }

    /// PublisherListener

    override fun onStreamCreated(p0: PublisherKit?, p1: Stream?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[PublisherListener] onStreamCreated")
        }
        delegate?.didCreatePublisherStream()
    }

    override fun onStreamDestroyed(p0: PublisherKit?, p1: Stream?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[PublisherListener] onStreamDestroyed")
        }
        unpublish()
    }

    override fun onError(p0: PublisherKit?, error: OpentokError?) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[PublisherListener] onError ${error?.message}")
        }
    }

    /// Private

    fun publish() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[VOIPProvider] publish")
        }

        publisher = Publisher.Builder(delegate?.context)
                .audioTrack(publisherSettings?.audioTrack ?: true)
                .videoTrack(publisherSettings?.videoTrack ?: true)
                .audioBitrate(publisherSettings?.audioBitrate ?: 400000)
                .frameRate(Publisher.CameraCaptureFrameRate.FPS_30)
                .resolution(Publisher.CameraCaptureResolution.HIGH)
                .build()

        publisher?.setPublisherListener(this)
        publisher?.publishVideo = false
        session?.publish(publisher)
    }

    fun unpublish() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[VOIPProvider] unpublish")
        }
        if (publisher != null) {
            session?.unpublish(publisher)
            publisher = null
        }
    }

    fun subscribe(stream: Stream) {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[VOIPProvider] subscribe")
        }

        subscriber = Subscriber.Builder(delegate?.context, stream).build()
        session?.subscribe(subscriber)
    }

    fun unsubscribe() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[VOIPProvider] unsubscribe")
        }

        if (subscriber != null) {
            session?.unsubscribe(subscriber)
            subscriber = null
        }


    }
}
