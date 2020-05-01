package com.flutter_opentok

import android.content.Context
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import com.opentok.android.AudioDeviceManager
import com.opentok.android.BaseAudioDevice
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import kotlinx.serialization.json.Json


class FlutterOpenTokView(
        var registrar: PluginRegistry.Registrar,
        override var context: Context,
        var viewId: Int,
        var args: Any?) : PlatformView, MethodChannel.MethodCallHandler, VoIPProviderDelegate, View.OnTouchListener {

    var publisherSettings: PublisherSettings? = null
    var enablePublisherVideo: Boolean? = null
    var switchedToSpeaker: Boolean = true
    var provider: VoIPProvider? = null
    var channel: MethodChannel
    val openTokView: FrameLayout
    var screenHeight: Int = LinearLayout.LayoutParams.MATCH_PARENT
    var screenWidth: Int = LinearLayout.LayoutParams.MATCH_PARENT
    var publisherHeight: Int = 500
    var publisherWidth: Int = 350

    init {
        val channelName = "plugins.indoor.solutions/opentok_$viewId"
        channel = MethodChannel(registrar.messenger(), channelName)

        val arguments: Map<*, *>? = args as? Map<*, *>
        if (arguments?.containsKey("height") == true)
            screenHeight = arguments?.get("height") as Int
        if (arguments?.containsKey("width") == true)
            screenWidth = arguments?.get("width") as Int

        if (arguments?.containsKey("publisherHeight") == true)
            publisherHeight = arguments?.get("publisherHeight") as Int
        if (arguments?.containsKey("publisherWidth") == true)
            publisherWidth = arguments?.get("publisherWidth") as Int

        openTokView = FrameLayout(context)
        openTokView.layoutParams = LinearLayout.LayoutParams(screenWidth, screenHeight)
        openTokView.setBackgroundColor(Color.WHITE)

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
    val subscriberView: View?
        get() {
            if (provider is OpenTokVoIPImpl)
                return (provider as OpenTokVoIPImpl).subscriberView
            return null
        }

    val publisherView: View?
        get() {
            if (provider is OpenTokVoIPImpl)
                return (provider as OpenTokVoIPImpl).publisherView
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

        if (publisherView != null) {
            val pubView: View = publisherView!!
            openTokView.addView(pubView)
            pubView.setOnTouchListener(this);
            val layout = FrameLayout.LayoutParams(publisherWidth, publisherHeight, Gravity.TOP or Gravity.RIGHT)
            layout.setMargins(20,20,20,20)
            pubView.layoutParams = layout
            if (pubView is GLSurfaceView) {
                (pubView as GLSurfaceView).setZOrderOnTop(true)
            }
        }
        channelInvokeMethod("onSessionConnect", null)
    }

    override fun didDisconnect() {
        channelInvokeMethod("onSessionDisconnect", null)
    }

    override fun didReceiveVideo() {
        if (FlutterOpentokPlugin.loggingEnabled) {
            print("[FlutterOpenTokView] Receive video")
        }

        if (subscriberView != null) {
            val subView: View = subscriberView!!
            if (openTokView.childCount > 0) {
                openTokView.removeAllViews()
                openTokView.addView(subView)
                openTokView.addView(publisherView)
            } else {
                openTokView.addView(subView)
            }

            if (subView is GLSurfaceView) {
                (subView as GLSurfaceView).setZOrderOnTop(true)
            }
        }
        channelInvokeMethod("onReceiveVideo", null)
    }

    override fun didCreateStream() {
        channelInvokeMethod("onCreateStream",null)
    }

    override fun didCreatePublisherStream() {
        channelInvokeMethod("onCreatePublisherStream", null)
    }

    /// TouchListener
    var dX: Float = 0F
    var dY: Float = 0F
    override fun onTouch(view: View?, event: MotionEvent?): Boolean {
        when (event!!.action) {
            MotionEvent.ACTION_DOWN -> {
                dX = view!!.x - event.rawX
                dY = view.y - event.rawY
            }
            MotionEvent.ACTION_MOVE -> {
                var newX = event.rawX + dX
                if (newX < 0)
                    newX = 0F
                if (newX > openTokView.width - view!!.width)
                    newX = (openTokView.width - view!!.width).toFloat()

                var newY = event.rawY + dY
                if (newY < 0)
                    newY = 0F
                if (newY > openTokView.height - view!!.height)
                    newY = (openTokView.height - view!!.height).toFloat()

                view!!.animate()
                        .x(newX)
                        .y(newY)
                        .setDuration(0)
                        .start()
            }
            else -> return false
        }
        return true
    }
}