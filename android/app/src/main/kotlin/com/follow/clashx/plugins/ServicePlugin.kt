package com.follow.clashx.plugins

import com.follow.clashx.GlobalState
import com.follow.clashx.models.VpnOptions
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


data object ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var flutterMethodChannel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "service")
        flutterMethodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = when (call.method) {
        "startVpn" -> {
            val data = call.argument<String>("data")
            if (data != null && data != "null" && data.isNotEmpty()) {
                try {
                    val options = Gson().fromJson(data, VpnOptions::class.java)
                    if (options != null) {
                        GlobalState.getCurrentVPNPlugin()?.handleStart(options)
                        result.success(true)
                    } else {
                        result.error("error", "Failed to parse VPN options", null)
                    }
                } catch (e: Exception) {
                    result.error("error", e.message, e.toString())
                }
            } else {
                result.error("error", "VPN options data is null or empty", null)
            }
        }

        "stopVpn" -> {
            GlobalState.getCurrentVPNPlugin()?.handleStop()
            result.success(true)
        }

        "init" -> {
            GlobalState.getCurrentAppPlugin()
                ?.requestNotificationsPermission()
            GlobalState.initServiceEngine()
            result.success(true)
        }

        "destroy" -> {
            handleDestroy()
            result.success(true)
        }

        else -> {
            result.notImplemented()
        }
    }

    private fun handleDestroy() {
        GlobalState.destroyServiceEngine()
    }
}
