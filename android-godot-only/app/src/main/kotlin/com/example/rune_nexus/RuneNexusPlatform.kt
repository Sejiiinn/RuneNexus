package com.example.rune_nexus

import android.content.Intent
import android.net.Uri
import android.os.CancellationSignal
import android.provider.Settings
import android.util.TypedValue
import androidx.annotation.Keep
import androidx.core.content.ContextCompat
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import java.util.concurrent.Executors
import java.io.File
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject

/** Android platform boundary for the Godot app. JSON results keep nullable values explicit. */
@Keep
class RuneNexusPlatform(engine: Godot, private val host: MainActivity) : GodotPlugin(engine) {
    private val worker = Executors.newSingleThreadExecutor()
    private val session by lazy { SessionStorage(host.applicationContext) }
    private val updater by lazy { AppUpdater(host) }
    private var signInCancellation: CancellationSignal? = null
    private var signOutRunning = false
    private var detached = false

    override fun getPluginName() = "RuneNexusPlatform"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("google_sign_in_completed", String::class.java),
        SignalInfo("google_sign_out_completed", String::class.java),
        SignalInfo("installed_version_ready", String::class.java),
        SignalInfo("update_completed", String::class.java, String::class.java),
    )

    @UsedByGodot
    fun application_support_path(): String = host.filesDir.absolutePath

    @UsedByGodot
    fun sp_to_logical(logical_size: Double): Double {
        if (!logical_size.isFinite() || logical_size <= 0.0) return logical_size
        val metrics = host.resources.displayMetrics
        val pixelsPerDp = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1f, metrics)
        val pixelsPerSp = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP, logical_size.toFloat(), metrics)
        if (!pixelsPerDp.isFinite() || pixelsPerDp <= 0f || !pixelsPerSp.isFinite() || pixelsPerSp <= 0f)
            return logical_size
        return (pixelsPerSp / pixelsPerDp).toDouble()
    }

    @UsedByGodot
    fun legacy_save_path(): String = File(host.cacheDir, "rune_nexus_save_v1.json").absolutePath

    @UsedByGodot
    fun device_preferences(): String = try {
        val file = File(host.filesDir, "graphics_settings_v1.json")
        json(true, "value" to if (file.isFile) file.readText() else null)
    } catch (_: Exception) {
        json(false, "error" to "device_preferences_unavailable")
    }

    @UsedByGodot
    fun session_read(): String = try {
        json(true, "value" to session.read())
    } catch (_: SessionUnreadableException) {
        json(false, "error" to "session_unreadable")
    } catch (_: Exception) {
        json(false, "error" to "session_storage_unavailable")
    }

    @UsedByGodot
    fun session_write(value: String): String = try {
        session.write(value)
        json(true)
    } catch (_: Exception) {
        json(false, "error" to "session_storage_unavailable")
    }

    @UsedByGodot
    fun session_delete(): String = try {
        session.delete()
        json(true)
    } catch (_: Exception) {
        json(false, "error" to "session_storage_unavailable")
    }

    @UsedByGodot
    fun sign_in_google(client_id: String): Boolean {
        if (client_id.isBlank() || detached || signInCancellation != null) return false
        val cancellation = CancellationSignal()
        signInCancellation = cancellation
        host.runOnUiThread {
            try {
                val request = GetCredentialRequest.Builder()
                    .addCredentialOption(GetSignInWithGoogleOption.Builder(client_id).build())
                    .build()
                CredentialManager.create(host).getCredentialAsync(
                    host, request, cancellation, ContextCompat.getMainExecutor(host),
                    object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                        override fun onResult(result: GetCredentialResponse) {
                            signInCancellation = null
                            val payload = try {
                                val credential = result.credential
                                require(credential is CustomCredential &&
                                    credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL)
                                json(true, "idToken" to GoogleIdTokenCredential.createFrom(credential.data).idToken)
                            } catch (_: Exception) {
                                json(false, "error" to "invalid_credential")
                            }
                            if (!detached) emitSignal("google_sign_in_completed", payload)
                        }

                        override fun onError(e: GetCredentialException) {
                            signInCancellation = null
                            val code = if (e is GetCredentialCancellationException)
                                "sign_in_cancelled" else "sign_in_unavailable"
                            if (!detached) emitSignal("google_sign_in_completed", json(false, "error" to code))
                        }
                    },
                )
            } catch (_: Exception) {
                signInCancellation = null
                if (!detached) emitSignal("google_sign_in_completed", json(false, "error" to "sign_in_unavailable"))
            }
        }
        return true
    }

    @UsedByGodot
    fun sign_out_google(): Boolean {
        if (detached || signOutRunning) return false
        signOutRunning = true
        host.runOnUiThread {
            try {
                CredentialManager.create(host).clearCredentialStateAsync(
                    ClearCredentialStateRequest(), null, ContextCompat.getMainExecutor(host),
                    object : CredentialManagerCallback<Void?, ClearCredentialException> {
                        override fun onResult(result: Void?) = finishSignOut(json(true))
                        override fun onError(e: ClearCredentialException) =
                            finishSignOut(json(false, "error" to "sign_out_unavailable"))
                    },
                )
            } catch (_: Exception) {
                finishSignOut(json(false, "error" to "sign_out_unavailable"))
            }
        }
        return true
    }

    private fun finishSignOut(payload: String) {
        signOutRunning = false
        if (!detached) emitSignal("google_sign_out_completed", payload)
    }

    @UsedByGodot
    fun installed_version(): String {
        var result = json(false, "error" to "update_failed")
        updater.perform("getInstalledVersion", emptyMap(), object : AppUpdater.Result {
            override fun success(value: Any?) { result = json(true, "value" to value) }
            override fun error(code: String, message: String) { result = json(false, "error" to code) }
        })
        return result
    }

    /** Computes the potentially large installed APK hash off the Godot render thread. */
    @UsedByGodot
    fun query_installed_version(): Boolean {
        if (detached) return false
        worker.execute {
            val payload = installed_version()
            host.runOnUiThread {
                if (!detached) emitSignal("installed_version_ready", payload)
            }
        }
        return true
    }

    @UsedByGodot
    fun download_update(url: String, sha256: String, size_bytes: Long, version_code: Long): Boolean =
        runUpdate("downloadUpdate", mapOf("url" to url, "sha256" to sha256,
            "sizeBytes" to size_bytes, "versionCode" to version_code))

    @UsedByGodot
    fun download_patch(url: String, sha256: String, size_bytes: Long, version_code: Long,
                       base_sha256: String, target_sha256: String, target_size_bytes: Long): Boolean =
        runUpdate("downloadPatch", mapOf("url" to url, "sha256" to sha256,
            "sizeBytes" to size_bytes, "versionCode" to version_code,
            "baseSha256" to base_sha256, "targetSha256" to target_sha256,
            "targetSizeBytes" to target_size_bytes))

    @UsedByGodot
    fun install_update(version_code: Long): Boolean =
        runUpdate("installUpdate", mapOf("versionCode" to version_code))

    private fun runUpdate(operation: String, args: Map<String, Any>): Boolean {
        if (detached) return false
        worker.execute {
            updater.perform(operation, args, object : AppUpdater.Result {
                override fun success(value: Any?) = completeUpdate(operation, json(true, "value" to value))
                override fun error(code: String, message: String) =
                    completeUpdate(operation, json(false, "error" to code))
            })
        }
        return true
    }

    private fun completeUpdate(operation: String, payload: String) {
        host.runOnUiThread {
            if (!detached) emitSignal("update_completed", operation, payload)
        }
    }

    @UsedByGodot
    fun open_app_settings() {
        host.runOnUiThread {
            host.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${host.packageName}")))
        }
    }

    fun detach() {
        detached = true
        signInCancellation?.cancel()
        signInCancellation = null
        worker.shutdownNow()
    }

    private fun json(ok: Boolean, vararg fields: Pair<String, Any?>): String =
        JSONObject().apply {
            put("ok", ok)
            fields.forEach { (key, value) -> put(key, JSONObject.wrap(value)) }
        }.toString()
}
