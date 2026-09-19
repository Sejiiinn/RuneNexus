package com.example.rune_nexus

import android.os.Bundle
import android.view.WindowManager
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotActivity
import org.godotengine.godot.plugin.GodotPlugin

/** 검수 패키지의 별도 프로세스에서 Flutter 없이 같은 Godot 렌더러를 실행한다. */
class GodotBenchmarkActivity : GodotActivity() {
    private var bridge: GodotBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onCreate(savedInstanceState)
    }

    override fun getHostPlugins(engine: Godot): Set<GodotPlugin> {
        val current = bridge ?: GodotBridge(engine).also { bridge = it }
        return setOf(current)
    }

    override fun getCommandLine(): MutableList<String> {
        val args = super.getCommandLine().toMutableList()
        args.addAll(listOf(
            "--main-pack", "res://rune_nexus.pck",
            "--rendering-method", "mobile",
            "--disable_godot_splash",
            "--",
            "--scenario=${textExtra("scenario", "normal")}",
            "--mode=${textExtra("mode", "standalone")}",
            "--duration=${textExtra("duration", "30").toDoubleOrNull()?.coerceIn(1.0, 3600.0) ?: 30.0}",
        ))
        return args
    }

    // Only benchmark values are accepted; arbitrary engine/scene arguments are never forwarded.
    private fun textExtra(name: String, fallback: String): String {
        val value = intent.extras?.get(name)?.toString() ?: return fallback
        return value.takeIf { it.length <= 64 && it.matches(Regex("[A-Za-z0-9_.-]+")) }
            ?: fallback
    }
}
