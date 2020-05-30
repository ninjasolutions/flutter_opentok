package com.flutter_opentok

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.Registrar

class FlutterOpentokPlugin : MethodChannel.MethodCallHandler {

  companion object {
    var loggingEnabled = false

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "flutter_opentok")
      channel.setMethodCallHandler(FlutterOpentokPlugin())

      registrar.platformViewRegistry().registerViewFactory("OpenTokRendererView", FlutterOpenTokViewFactory(registrar));
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

}
