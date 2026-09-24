package com.example.rune_nexus

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotActivity
import org.godotengine.godot.plugin.GodotPlugin

class MainActivity : GodotActivity() {
    private var platform: RuneNexusPlatform? = null

    override fun onCreate(state: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onCreate(state)
        window.decorView.post(::hideSystemBars)
    }

    override fun getHostPlugins(engine: Godot): Set<GodotPlugin> =
        setOf(RuneNexusPlatform(engine, this).also { platform = it })

    override fun onDestroy() {
        platform?.detach()
        platform = null
        super.onDestroy()
    }

    override fun onWindowFocusChanged(focused: Boolean) {
        super.onWindowFocusChanged(focused)
        if (focused) hideSystemBars()
    }

    @Suppress("DEPRECATION")
    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.apply {
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsets.Type.systemBars())
            }
        } else {
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
    }

    override fun getCommandLine(): MutableList<String> = (super.getCommandLine() + buildList {
        addAll(listOf("--main-pack", "res://rune_nexus.pck", "--rendering-method",
            "mobile", "--disable_godot_splash", "--background_color", "#101b20", "--", "--app"))
        intent.getStringExtra("camera")?.takeIf { it == "drone" || it == "angled" }
            ?.let { add("--camera=$it") }
        if (intent.getBooleanExtra("profileApp", false)) add("--profile-app")
    }).toMutableList()
}
