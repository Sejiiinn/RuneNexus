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
    private val combatResponse = AtomicReference("{}")
    private var combatCommand = ""
    private var combatPendingSequence = -1L
    private var combatAppliedSequence = -1L
    private var combatStateRevision = -1L
    private val sessionActive = AtomicBoolean(false)
    private val sessionActivationRevision = AtomicLong()
    private val ready = AtomicBoolean(false)
    private val error = AtomicReference<String?>(null)
    private val submitted = AtomicLong()
    private val consumed = AtomicLong()
    private val superseded = AtomicLong()

    override fun getPluginName() = "RuneNexusPreview"

    fun submitFrame(json: String) {
        // 기존 검수 앱의 문자열 계약은 유지하고 파싱은 슬롯 잠금 밖에서 처리.
        submitFrameV2(epochOf(json), json)
    }

    @Synchronized
    fun submitFrameV2(epoch: Long, json: String): String {
        if (epoch != sceneEpoch) return "{}"
        // 소비가 늦으면 지난 프레임만 교체하고 큐·메모리 누적 방지.
        if (frame.isNotEmpty()) superseded.incrementAndGet()
        frame = json
        submitted.incrementAndGet()
        // 제출 완료는 적용 ACK가 아님. Godot가 이미 적용한 최신 응답만 반환.
        return presentation.get()
    }

    /** Combat commands must never use the lossy presentation-frame mailbox. */
    @Synchronized
    fun submitCombat(epoch: Long, json: String): String {
        if (epoch != sceneEpoch) return "{}"
        val packet = runCatching { JSONObject(json) }.getOrNull() ?: return "{}"
        val sequence = packet.optLong("sequence", -1L)
        if (packet.optLong("epoch", -1L) != epoch || sequence < 0) return "{}"
        if (sequence <= combatAppliedSequence) return combatResponse.get()
        val newerBootstrap = packet.has("bootstrap") &&
            sequence > combatPendingSequence
        if (combatPendingSequence < 0 || combatPendingSequence == sequence || newerBootstrap) {
            combatPendingSequence = sequence
            combatCommand = json
        }
        return combatResponse.get()
    }

    @Synchronized
    fun latestSessionState(epoch: Long): String =
        if (epoch == sceneEpoch && !resetPending) combatResponse.get() else "{}"

    @Synchronized
    fun setSessionActive(active: Boolean) {
        // Publish the generation before opening the gate. Godot discards the
        // first delta after resume even if its render loop slept through pause.
        if (active && !sessionActive.get()) sessionActivationRevision.incrementAndGet()
        sessionActive.set(active)
    }

    @UsedByGodot
    fun session_activation_revision(): Long = sessionActivationRevision.get()

    /** Independent of Dart polling: checked before each native simulation tick. */
    @UsedByGodot
    fun is_session_active(): Boolean = sessionActive.get()

    @Synchronized
    fun clearScene(expectedEpoch: Long? = null) {
        if (expectedEpoch != null && expectedEpoch != sceneEpoch) return
        frame = ""
        resetPending = true
        options.set("")
        presentation.set("{}")
        combatResponse.set("{}")
        combatCommand = ""
        combatPendingSequence = -1L
        combatAppliedSequence = -1L
        combatStateRevision = -1L
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

    @Synchronized
    fun status(viewAttached: Boolean): Map<String, Any?> = mapOf(
        "ready" to ready.get(),
        "error" to error.get(),
        "viewAttached" to viewAttached,
        "engineVersion" to "4.7.2.stable",
        "nativeCombatVersion" to 1,
        "nativeSessionVersion" to 1,
        "sessionActive" to sessionActive.get(),
        "stateRevision" to combatStateRevision,
        "combatSequence" to combatAppliedSequence,
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

    @Synchronized
    @UsedByGodot
    fun take_combat(): String {
        if (resetPending) return ""
        val current = combatCommand
        combatCommand = ""
        return current
    }

    @Synchronized
    @UsedByGodot
    fun report_combat(json: String) {
        val packet = runCatching { JSONObject(json) }.getOrNull() ?: return
        val sequence = packet.optLong("ackSequence", -1L)
        if (resetPending || packet.optLong("epoch", -1L) != sceneEpoch ||
            sequence < combatAppliedSequence) return
        val revision = packet.optLong("stateRevision", -1L)
        if (revision >= 0 && revision < combatStateRevision) return
        combatResponse.set(json)
        combatAppliedSequence = sequence
        if (revision >= 0) combatStateRevision = revision
        if (combatPendingSequence <= sequence) {
            combatPendingSequence = -1L
            combatCommand = ""
        }
    }

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
        setSessionActive(false)
        error.set(message)
        ready.set(false)
        presentation.set("{}")
        combatResponse.set("{}")
    }

    override fun onGodotTerminating() {
        clearScene()
        report_error("Godot 렌더러가 종료되었습니다.")
    }
}
