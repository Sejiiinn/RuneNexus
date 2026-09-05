package com.example.rune_nexus

import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.ClearCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var signInCancellation: CancellationSignal? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // 직렬 백그라운드 큐: 파일 교체와 Keystore 접근 중 UI 스레드 차단 방지.
        val storage by lazy { SessionStorage(applicationContext) }
        MethodChannel(
            messenger,
            "rune_nexus/session_storage",
            io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "read" -> result.success(storage.read())
                    "write" -> {
                        val value = call.argument<String>("value")
                        if (value == null) {
                            result.error("invalid_argument", "Session value required", null)
                        } else {
                            storage.write(value)
                            result.success(null)
                        }
                    }
                    "delete" -> {
                        storage.delete()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: SessionUnreadableException) {
                result.error("session_unreadable", "Session encryption unavailable", null)
            } catch (_: Exception) {
                result.error("session_storage_unavailable", "Session storage unavailable", null)
            }
        }
        MethodChannel(messenger, "rune_nexus/google_identity")
            .setMethodCallHandler { call, channelResult ->
                if (call.method == "clearCredentialState") {
                    try {
                        CredentialManager.create(this).clearCredentialStateAsync(
                            ClearCredentialStateRequest(),
                            null,
                            ContextCompat.getMainExecutor(this),
                            object : CredentialManagerCallback<Void?, ClearCredentialException> {
                                override fun onResult(result: Void?) {
                                    channelResult.success(null)
                                }

                                override fun onError(e: ClearCredentialException) {
                                    channelResult.error("sign_out_unavailable", "Credential state unavailable", null)
                                }
                            },
                        )
                    } catch (_: Exception) {
                        channelResult.error("sign_out_unavailable", "Credential state unavailable", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "signIn") {
                    channelResult.notImplemented()
                    return@setMethodCallHandler
                }
                val clientId = call.argument<String>("clientId")
                if (clientId.isNullOrBlank()) {
                    channelResult.error("invalid_argument", "Server client ID required", null)
                    return@setMethodCallHandler
                }
                if (signInCancellation != null) {
                    channelResult.error("sign_in_in_progress", "Sign in already running", null)
                    return@setMethodCallHandler
                }
                val cancellation = CancellationSignal()
                signInCancellation = cancellation
                try {
                    val request = GetCredentialRequest.Builder()
                        .addCredentialOption(GetSignInWithGoogleOption.Builder(clientId).build())
                        .build()
                    CredentialManager.create(this).getCredentialAsync(
                        this,
                        request,
                        cancellation,
                        ContextCompat.getMainExecutor(this),
                        object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                            override fun onResult(result: GetCredentialResponse) {
                                signInCancellation = null
                                try {
                                    val credential = result.credential
                                    if (credential !is CustomCredential ||
                                        credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                                    ) {
                                        channelResult.error("invalid_credential", "Unsupported credential", null)
                                        return
                                    }
                                    channelResult.success(GoogleIdTokenCredential.createFrom(credential.data).idToken)
                                } catch (_: Exception) {
                                    channelResult.error("invalid_credential", "Unable to parse Google credential", null)
                                }
                            }

                            override fun onError(e: GetCredentialException) {
                                signInCancellation = null
                                val code = if (e is GetCredentialCancellationException)
                                    "sign_in_cancelled" else "sign_in_unavailable"
                                channelResult.error(code, "Google sign in did not complete", null)
                            }
                        },
                    )
                } catch (_: Exception) {
                    signInCancellation = null
                    channelResult.error("sign_in_unavailable", "Google sign in unavailable", null)
                }
            }
    }

    override fun onDestroy() {
        signInCancellation?.cancel()
        signInCancellation = null
        super.onDestroy()
    }
}
