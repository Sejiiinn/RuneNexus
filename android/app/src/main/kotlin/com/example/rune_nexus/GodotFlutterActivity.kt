package com.example.rune_nexus

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** 본게임과 별도 검수 앱이 공유하는 Flutter·Godot 연결 진입점. */
open class GodotFlutterActivity : FlutterActivity() {
    private var godotChannel: MethodChannel? = null
    internal var godotActivityStarted = false
        private set
    internal var godotActivityResumed = false
        private set

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        godotChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "rune_nexus/godot_preview",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> result.success(GodotRuntime.isReady())
                    "getMetrics" -> result.success(GodotRuntime.latestMetrics())
                    "getPresentation" -> result.success(GodotRuntime.latestPresentation())
                    "getStatus" -> result.success(GodotRuntime.status())
                    "clearScene" -> {
                        GodotRuntime.clearScene()
                        result.success(null)
                    }
                    "submitFrame", "setOptions" -> {
                        val json = call.arguments as? String
                        if (json.isNullOrEmpty()) {
                            result.error("invalid_argument", "A non-empty JSON string is required.", null)
                        } else {
                            if (call.method == "submitFrame") {
                                GodotRuntime.submitFrame(json)
                            } else {
                                GodotRuntime.setOptions(json)
                            }
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "rune_nexus/godot_view",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
                    GodotRuntime.BattlefieldView(context, this@GodotFlutterActivity)
            },
        )
    }

    override fun onStart() {
        super.onStart()
        godotActivityStarted = true
        GodotRuntime.syncActivity(this)
    }

    override fun onResume() {
        super.onResume()
        godotActivityResumed = true
        GodotRuntime.syncActivity(this)
    }

    override fun onPause() {
        godotActivityResumed = false
        GodotRuntime.syncActivity(this)
        super.onPause()
    }

    override fun onStop() {
        godotActivityStarted = false
        GodotRuntime.syncActivity(this)
        super.onStop()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        GodotRuntime.configurationChanged(this, newConfig)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        GodotRuntime.activityResult(this, requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        GodotRuntime.permissionsResult(this, requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        godotChannel?.setMethodCallHandler(null)
        godotChannel = null
        GodotRuntime.releaseActivity(this)
        super.onDestroy()
    }
}
