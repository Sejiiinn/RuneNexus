package com.example.rune_nexus

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotHost
import org.godotengine.godot.plugin.GodotPlugin
import java.lang.ref.WeakReference

/** 화면 수명과 분리한 프로세스당 단일 엔진. Godot AAR는 종료 후 재초기화를 지원하지 않음. */
internal object GodotRuntime : GodotHost {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var hostActivity = WeakReference<GodotFlutterActivity>(null)
    private var engine: Godot? = null
    private var bridge: GodotBridge? = null
    private var container: FrameLayout? = null
    private var activeView: BattlefieldView? = null
    private var engineStarted = false
    private var engineResumed = false
    private var initializing = false
    private var failure: String? = null

    override fun getActivity(): Activity? = hostActivity.get()
    override fun getGodot(): Godot = checkNotNull(engine)
    override fun getHostPlugins(engine: Godot): Set<GodotPlugin> = setOf(checkNotNull(bridge))
    override fun getCommandLine(): List<String> = listOf(
        "--main-pack", "res://rune_nexus.pck",
        "--rendering-method", "mobile",
        "--disable_godot_splash",
    )

    fun isReady() = failure == null && activeView?.attached == true && bridge?.isReady() == true
    fun latestMetrics(): String = bridge?.latestMetrics() ?: "{}"
    fun latestPresentation(): String =
        if (activeView?.attached == true) bridge?.latestPresentation() ?: "{}" else "{}"

    fun status(): Map<String, Any?> {
        val attached = activeView?.attached == true
        val status: MutableMap<String, Any?> = bridge?.status(attached)?.toMutableMap() ?: mutableMapOf(
            "ready" to false,
            "error" to null,
            "viewAttached" to attached,
            "engineVersion" to "4.7.2.stable",
        )
        status["ready"] = isReady()
        status["engineInitialized"] = container != null
        if (failure != null) {
            status["ready"] = false
            status["error"] = failure
        }
        return status
    }

    fun submitFrame(json: String) { bridge?.submitFrame(json) }
    fun setOptions(json: String) { bridge?.setOptions(json) }
    fun clearScene() { bridge?.clearScene() }

    private fun attachRenderer(view: BattlefieldView) {
        if (initializing || failure != null || view.disposed) return
        if (activeView !== view) {
            // 교체 중인 이전 PlatformView의 늦은 dispose가 새 전장을 지우지 않도록 소유권 전환.
            activeView = null
            updateEngineLifecycle()
            hostActivity = WeakReference(view.owner)
            activeView = view
            clearScene()
        }
        try {
            initializing = true
            if (container == null) {
                val current = Godot.getInstance(view.owner.applicationContext)
                engine = current
                bridge = GodotBridge(current)
                check(current.initEngine(this, getCommandLine(), getHostPlugins(current))) {
                    "Godot engine initialization failed."
                }
                container = checkNotNull(current.onInitRenderView(this)) {
                    "Godot render view initialization failed."
                }
            }
            val renderContainer = checkNotNull(container)
            if (renderContainer.parent !== view.layout) {
                (renderContainer.parent as? ViewGroup)?.removeView(renderContainer)
                view.layout.addView(renderContainer, FrameLayout.LayoutParams(-1, -1))
            }
            updateEngineLifecycle()
        } catch (error: Exception) {
            recordFailure(error.message ?: "Godot 전장을 초기화하지 못했습니다.")
        } catch (error: LinkageError) {
            recordFailure(error.message ?: "Godot 네이티브 라이브러리를 불러오지 못했습니다.")
        } finally {
            initializing = false
        }
    }

    private fun updateEngineLifecycle() {
        val current = engine ?: return
        if (container == null) return
        val activity = hostActivity.get()
        val shouldStart = failure == null && activity?.godotActivityStarted == true &&
            activeView?.attached == true
        val shouldResume = shouldStart && activity?.godotActivityResumed == true
        try {
            if (engineResumed && !shouldResume) {
                engineResumed = false
                current.onPause(this)
            }
            if (engineStarted && !shouldStart) {
                engineStarted = false
                current.onStop(this)
            }
            if (!engineStarted && shouldStart) {
                engineStarted = true
                current.onStart(this)
            }
            if (!engineResumed && shouldResume) {
                engineResumed = true
                current.onResume(this)
            }
        } catch (error: Exception) {
            recordFailure(error.message ?: "Godot 전장 상태를 변경하지 못했습니다.")
        } catch (error: LinkageError) {
            recordFailure(error.message ?: "Godot 네이티브 연결이 중단되었습니다.")
        }
    }

    private fun recordFailure(message: String) {
        failure = message
        bridge?.report_error(message)
        // 렌더 오류를 앱 종료로 확대하지 않고 Flutter 2D 폴백에 전달.
        activeView?.layout?.removeAllViews()
    }

    fun syncActivity(activity: GodotFlutterActivity) {
        if (hostActivity.get() === activity) updateEngineLifecycle()
    }

    fun releaseActivity(activity: GodotFlutterActivity) {
        if (hostActivity.get() !== activity) return
        activeView?.dispose()
        hostActivity.clear()
        // 앱 화면 종료에도 정지된 엔진은 유지. 재생성된 Activity는 같은 컨테이너 재사용.
    }

    fun configurationChanged(activity: GodotFlutterActivity, configuration: Configuration) {
        if (hostActivity.get() === activity && container != null && failure == null) {
            engine?.onConfigurationChanged(configuration)
        }
    }

    fun activityResult(activity: GodotFlutterActivity, requestCode: Int, resultCode: Int, data: Intent?) {
        if (hostActivity.get() === activity && container != null && failure == null) {
            engine?.onActivityResult(requestCode, resultCode, data)
        }
    }

    fun permissionsResult(
        activity: GodotFlutterActivity,
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        if (hostActivity.get() === activity && container != null && failure == null) {
            engine?.onRequestPermissionsResult(
                requestCode, Array<String?>(permissions.size) { permissions[it] }, grantResults,
            )
        }
    }

    override fun onGodotForceQuit(instance: Godot) {
        mainHandler.post {
            recordFailure("Godot 렌더러가 종료되었습니다.")
            updateEngineLifecycle()
        }
    }

    override fun onGodotRestartRequested(instance: Godot) {
        mainHandler.post {
            recordFailure("Godot 렌더러를 다시 시작해야 합니다.")
            updateEngineLifecycle()
        }
    }

    class BattlefieldView(context: Context, val owner: GodotFlutterActivity) :
        PlatformView, View.OnAttachStateChangeListener {
        val layout = FrameLayout(context)
        var attached = false
            private set
        var disposed = false
            private set

        init { layout.addOnAttachStateChangeListener(this) }

        override fun getView(): View = layout

        override fun onViewAttachedToWindow(view: View) {
            if (disposed) return
            attached = true
            attachRenderer(this)
        }

        override fun onViewDetachedFromWindow(view: View) {
            attached = false
            if (activeView === this) updateEngineLifecycle()
        }

        override fun dispose() {
            if (disposed) return
            disposed = true
            attached = false
            if (activeView === this) {
                updateEngineLifecycle()
                clearScene()
                activeView = null
            }
            layout.removeOnAttachStateChangeListener(this)
            layout.removeAllViews()
        }
    }
}
