package com.example.rune_nexus

import androidx.annotation.Keep
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject

/** Flutter UI 스레드와 Godot 렌더 스레드 사이의 최신 상태 전달. */
@Keep
class GodotBridge(engine: Godot) : GodotPlugin(engine) {
    private var frame = ""
    private var resetPending = false
    private var sceneEpoch = 0L
    private val options = AtomicReference("")
    private val metrics = AtomicReference("{}")
    private val presentation = AtomicReference("{}")
    private val ready = AtomicBoolean(false)
    private val error = AtomicReference<String?>(null)
    private val submitted = AtomicLong()
    private val consumed = AtomicLong()
    private val superseded = AtomicLong()

    override fun getPluginName() = "RuneNexusPreview"

    @Synchronized
    fun submitFrame(json: String) {
        if (epochOf(json) != sceneEpoch) return
        // 소비가 늦으면 지난 프레임만 교체하고 큐·메모리 누적 방지.
        if (frame.isNotEmpty()) superseded.incrementAndGet()
        frame = json
        submitted.incrementAndGet()
    }

    @Synchronized
    fun clearScene(expectedEpoch: Long? = null) {
        if (expectedEpoch != null && expectedEpoch != sceneEpoch) return
        frame = ""
        resetPending = true
        options.set("")
        presentation.set("{}")
    }

    @Synchronized
    fun beginScene(epoch: Long) {
        if (epoch < sceneEpoch) return
        sceneEpoch = epoch
        clearScene()
    }

    private fun epochOf(json: String): Long =
        runCatching { JSONObject(json).optLong("sceneEpoch", 0L) }.getOrDefault(-1L)

    @Synchronized
    fun setOptions(json: String) {
        if (epochOf(json) != sceneEpoch) return
        options.set(json)
    }

    fun isReady() = ready.get()
    fun latestMetrics(): String = metrics.get()
    fun latestPresentation(): String = presentation.get()

    fun status(viewAttached: Boolean): Map<String, Any?> = mapOf(
        "ready" to ready.get(),
        "error" to error.get(),
        "viewAttached" to viewAttached,
        "engineVersion" to "4.7.2.stable",
        "submitted" to submitted.get(),
        "consumed" to consumed.get(),
        "superseded" to superseded.get(),
    )

    @Synchronized
    @UsedByGodot
    fun take_frame(): String {
        // 새 프레임이 즉시 도착해도 장면 초기화 요청은 먼저 한 번 소비.
        if (resetPending) {
            resetPending = false
            return "{\"reset\":true,\"sceneEpoch\":$sceneEpoch}"
        }
        val current = frame
        frame = ""
        if (current.isNotEmpty()) consumed.incrementAndGet()
        return current
    }

    @UsedByGodot
    fun take_options(): String = options.getAndSet("")

    @UsedByGodot
    fun report_ready() {
        error.set(null)
        ready.set(true)
    }

    @UsedByGodot
    fun report_metrics(json: String) {
        metrics.set(json)
    }

    @Synchronized
    @UsedByGodot
    fun report_presentation(json: String) {
        if (!resetPending && epochOf(json) == sceneEpoch) presentation.set(json)
    }

    @UsedByGodot
    fun report_error(message: String) {
        error.set(message)
        ready.set(false)
        presentation.set("{}")
    }

    override fun onGodotTerminating() {
        clearScene()
        report_error("Godot 렌더러가 종료되었습니다.")
    }
}
