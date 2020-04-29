package com.flutter_opentok

import android.content.Context
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class FlutterOpenTokViewFactory(var registrar: PluginRegistry.Registrar) :
        PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val arguments: Map<*, *>? = args as? Map<*, *>
        if (arguments?.get("loggingEnabled") as Boolean) {
            FlutterOpentokPlugin.loggingEnabled = true
        }

        val view = FlutterOpenTokView(registrar, context, viewId, args)
        view.setup()

        // Return the view
        return view
    }
}