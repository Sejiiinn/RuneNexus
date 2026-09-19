package com.example.rune_nexus

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** 별도 설치·메모리 세션의 검수 앱도 본게임과 같은 네이티브 런타임 사용. */
class GodotPreviewActivity : GodotFlutterActivity() {
    private var benchmarkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        benchmarkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "rune_nexus/godot_benchmark",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "openBenchmark") {
                    result.notImplemented()
                } else {
                    val launch = Intent(this, GodotBenchmarkActivity::class.java)
                    for (key in listOf("scenario", "mode", "duration")) {
                        val value = call.argument<Any>(key)?.toString()
                        if (value != null) launch.putExtra(key, value)
                    }
                    if (!launch.hasExtra("mode")) launch.putExtra("mode", "flutter_handoff")
                    startActivity(launch)
                    result.success(null)
                }
            }
        }
    }

    override fun onDestroy() {
        benchmarkChannel?.setMethodCallHandler(null)
        benchmarkChannel = null
        super.onDestroy()
    }
}
