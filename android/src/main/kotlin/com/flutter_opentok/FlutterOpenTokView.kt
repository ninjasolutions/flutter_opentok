package com.flutter_opentok

import android.content.Context
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import kotlinx.serialization.json.*
import java.lang.Exception
import com.opentok.android.*

class FlutterOpenTokView(
        var registrar: PluginRegistry.Registrar,
        override var context: Context,
        var viewId: Int,
        var args: Any?) : PlatformView, MethodChannel.MethodCallHandler, VoIPProviderDelegate {

    var publisherSettings: PublisherSettings? = null
    var enablePublisherVideo: Boolean? = null
    var switchedToSpeaker: Boolean = true
    var provider: VoIPProvider? = null
    var channel: MethodChannel
    val openTokView: LinearLayout
//    var screenHeight: Int? = null
//    var screenWidth: Int? = null

    init {
        val channelName = "plugins.indoor.solutions/opentok_$viewId"
        channel = MethodChannel(registrar.messenger(), channelName)

        openTokView = LinearLayout(context)
        openTokView.layoutParams = LinearLayout.LayoutParams(400 , 400)
        openTokView.setBackgroundColor(Color.WHITE)

        val arguments: Map<*, *>? = args as? Map<*, *>
//        screenHeight = arguments?.get("height") as? Int
//        screenWidth = arguments?.get("width") as? Int
        val publisherArg = arguments?.get("publisherSettings") as? String
        try {
            publisherSettings = publisherArg?.let { Json.parse(PublisherSettings.serializer(), it) }
        } catch (e: Exception) {
            if (FlutterOpentokPlugin.loggingEnabled) {
                print("OpenTok publisher settings error: ${e.message}")
            }
        }

        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[FlutterOpenTokViewController] initialized")
        }

    }

    fun setup() {
        // Create VoIP provider
        createProvider()

        // Listen for method calls from Dart.
        channel.setMethodCallHandler(this)
    }

    override fun getView(): View {
        return openTokView
    }

    override fun dispose() {

    }

    fun configureAudioSession() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[FlutterOpenTokViewController] Configure audio session")
            print("[FlutterOpenTokViewController] Switched to speaker = $switchedToSpeaker")
        }

        if (switchedToSpeaker) {
            AudioDeviceManager.getAudioDevice().setOutputMode(BaseAudioDevice.OutputMode.SpeakerPhone);
        } else {
            AudioDeviceManager.getAudioDevice().setOutputMode(BaseAudioDevice.OutputMode.Handset);
        }
    }

    // Convenience getter for current video view based on provider implementation
    val videoView: View?
        get() {
            if (provider is OpenTokVoIPImpl)
                return (provider as OpenTokVoIPImpl).subscriberView
            return null
        }

    /** Create an instance of VoIPProvider. This is what implements VoIP for the application.*/
    private fun createProvider() {
        provider = OpenTokVoIPImpl(delegate = this, publisherSettings = publisherSettings)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "create") {
            if (call.arguments == null) return

            val methodArgs = call.arguments as? Map<String, Any>
            val apiKey = methodArgs?.get("apiKey") as? String
            val sessionId = methodArgs?.get("sessionId") as? String
            val token = methodArgs?.get("token") as? String

            if (apiKey != null && sessionId != null && token != null) {
                provider?.connect(apiKey, sessionId, token)
                result.success(null)
            } else {
                result.error("CREATE_ERROR", "Android could not extract flutter arguments in method: (create)","")
            }
        } else if (call.method == "destroy") {
            provider?.disconnect()
            result.success(null)
        } else if (call.method == "enablePublisherVideo") {
            provider?.enablePublisherVideo()
            result.success(null)
        } else if (call.method == "disablePublisherVideo") {
            provider?.disablePublisherVideo()
            result.success(null)
        } else if (call.method == "unmutePublisherAudio") {
            provider?.unmutePublisherAudio()
            result.success(null)
        } else if (call.method == "mutePublisherAudio") {
            provider?.mutePublisherAudio()
            result.success(null)
        } else if (call.method == "muteSubscriberAudio") {
            provider?.muteSubscriberAudio()
            result.success(null)
        } else if (call.method == "unmuteSubscriberAudio") {
            provider?.unmuteSubscriberAudio()
            result.success(null)
        } else if (call.method == "switchAudioToSpeaker") {
            switchedToSpeaker = true
            configureAudioSession()
            result.success(null)
        } else if (call.method == "switchAudioToReceiver") {
            switchedToSpeaker = false
            configureAudioSession()
            result.success(null)
        } else if (call.method == "getSdkVersion") {
            result.success("1")
        } else if (call.method == "switchCamera") {
            provider?.switchCamera()
            result.success(null)
        } else {
            result.notImplemented()
        }
    }

    fun channelInvokeMethod(method: String, arguments: Any?) {
        channel.invokeMethod(method, arguments, object: MethodChannel.Result {
            override fun notImplemented() {
                if (FlutterOpentokPlugin.loggingEnabled) {
                    print ("Method $method is not implemented")
                }
            }

            override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
                if (FlutterOpentokPlugin.loggingEnabled) {
                    print ("Method $method failed with error $errorMessage")
                }
            }

            override fun success(result: Any?) {
                if (FlutterOpentokPlugin.loggingEnabled) {
                    print ("Method $method succeeded")
                }
            }

        })
    }

    /// VoIPProviderDelegate

    override fun willConnect() {
        channelInvokeMethod("onWillConnect", null)
        if (enablePublisherVideo == true) {
            provider?.isAudioOnly = false
        }
    }

    override fun didConnect() {
        configureAudioSession()

        channelInvokeMethod("onSessionConnect", null)
    }

    override fun didDisconnect() {
        channelInvokeMethod("onSessionDisconnect", null)
    }

    override fun didReceiveVideo() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[FlutterOpenTokView] Receive video")
        }

        videoView?.let { openTokView.addView(videoView) }
        videoView?.layoutParams = LinearLayout.LayoutParams(200,200)
        videoView?.setBackgroundColor(Color.GREEN)
        channelInvokeMethod("onReceiveVideo", null)
    }

    override fun didCreateStream() {
        channelInvokeMethod("onCreateStream",null)
    }

    override fun didCreatePublisherStream() {
        channelInvokeMethod("onCreatePublisherStream", null)
    }
}