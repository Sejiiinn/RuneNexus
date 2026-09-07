package com.example.rune_nexus

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

/** 직렬 작업 큐에서 다운로드·해시·APK 검증 수행. */
class AppUpdater(private val activity: Activity, messenger: BinaryMessenger) {
    private val directory = File(activity.cacheDir, "updates")
    private val apk = File(directory, "update.apk")
    private val metadata = File(directory, "update.properties")
    private val channel = MethodChannel(
        messenger, "rune_nexus/app_update", StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )

    init {
        channel.setMethodCallHandler { call, result ->
            val changesFile = call.method == "downloadUpdate" || call.method == "downloadPatch" || call.method == "installUpdate"
            if (changesFile && !updateInProgress.compareAndSet(false, true)) {
                result.error("update_in_progress", "Application update already running", null)
                return@setMethodCallHandler
            }
            var completesOnMainThread = false
            try {
                when (call.method) {
                    "getInstalledVersion" -> {
                        val installed = installedPackage()
                        if (metadata.exists()) {
                            val saved = java.util.Properties().apply { metadata.inputStream().use { load(it) } }
                            if ((saved.getProperty("versionCode")?.toLongOrNull() ?: 0) <= version(installed)) {
                                apk.delete()
                                metadata.delete()
                            }
                        }
                        result.success(mapOf(
                            "versionCode" to version(installed),
                            "versionName" to installed.versionName,
                            "packageName" to installed.packageName,
                            "apkSha256" to if (activity.applicationInfo.splitSourceDirs.isNullOrEmpty())
                                ApkDelta.sha256(File(activity.applicationInfo.sourceDir)) else null,
                        ))
                    }
                    "downloadUpdate" -> {
                        val url = requireNotNull(call.argument<String>("url"))
                        val hash = requireNotNull(call.argument<String>("sha256"))
                        val size = requireNotNull(call.argument<Number>("sizeBytes")).toLong()
                        val expectedVersion = requireNotNull(call.argument<Number>("versionCode")).toLong()
                        require(hash.matches(Regex("[0-9a-fA-F]{64}")))
                        require(size in 1..MAX_APK_SIZE)
                        require(expectedVersion > version(installedPackage()))
                        download(url, hash, size, expectedVersion)
                        result.success(null)
                    }
                    "downloadPatch" -> {
                        try {
                            val url = requireNotNull(call.argument<String>("url"))
                            val hash = requireNotNull(call.argument<String>("sha256"))
                            val size = requireNotNull(call.argument<Number>("sizeBytes")).toLong()
                            val expectedVersion = requireNotNull(call.argument<Number>("versionCode")).toLong()
                            val targetHash = requireNotNull(call.argument<String>("targetSha256"))
                            val targetSize = requireNotNull(call.argument<Number>("targetSizeBytes")).toLong()
                            val baseHash = requireNotNull(call.argument<String>("baseSha256"))
                            require(activity.applicationInfo.splitSourceDirs.isNullOrEmpty())
                            require(expectedVersion > version(installedPackage()))
                            downloadPatch(url, hash, size, expectedVersion, baseHash, targetHash, targetSize)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("update_patch_failed", "Unable to apply application patch", null)
                        }
                    }
                    "installUpdate" -> {
                        val expectedVersion = requireNotNull(call.argument<Number>("versionCode")).toLong()
                        val saved = java.util.Properties().apply { metadata.inputStream().use { load(it) } }
                        require(saved.getProperty("versionCode").toLong() == expectedVersion)
                        verifyFile(apk, saved.getProperty("sha256"), saved.getProperty("sizeBytes").toLong(), expectedVersion)
                        completesOnMainThread = true
                        activity.runOnUiThread {
                            try {
                                check(!activity.isFinishing && !activity.isDestroyed)
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                    !activity.packageManager.canRequestPackageInstalls()) {
                                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:${activity.packageName}")))
                                    result.success("permissionRequired")
                                } else {
                                    val uri = FileProvider.getUriForFile(activity,
                                        "${activity.packageName}.app_updates", apk)
                                    activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, "application/vnd.android.package-archive")
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    })
                                    result.success("installerOpened")
                                }
                            } catch (_: Exception) {
                                result.error("update_install_failed", "Unable to open Android installer", null)
                            } finally {
                                updateInProgress.set(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: SignatureMismatchException) {
                result.error("update_signature_mismatch", "Update must use the installed application signing key", null)
            } catch (_: Exception) {
                result.error("update_failed", "Unable to download or verify application update", null)
            } finally {
                if (changesFile && !completesOnMainThread) updateInProgress.set(false)
            }
        }
    }

    private fun download(address: String, hash: String, size: Long, expectedVersion: Long) {
        check(directory.mkdirs() || directory.isDirectory)
        val temporary = File(directory, "update.part")
        // 새 다운로드 실패 시 이전 파일이 잘못 설치되지 않도록 메타데이터부터 폐기.
        metadata.delete()
        apk.delete()
        try {
            downloadFile(address, temporary, hash, size)
            verifyFile(temporary, hash, size, expectedVersion)
            saveDownloaded(temporary, hash, size, expectedVersion)
        } finally {
            temporary.delete()
        }
    }

    private fun downloadPatch(address: String, hash: String, size: Long, expectedVersion: Long,
                              baseHash: String, targetHash: String, targetSize: Long) {
        require(targetSize in 1..MAX_APK_SIZE)
        val base = File(activity.applicationInfo.sourceDir)
        require(base.length() in 1..MAX_APK_SIZE && ApkDelta.sha256(base).equals(baseHash, ignoreCase = true))
        check(directory.mkdirs() || directory.isDirectory)
        val patch = File(directory, "update.patch")
        val temporary = File(directory, "update.part")
        metadata.delete()
        apk.delete()
        try {
            downloadFile(address, patch, hash, size)
            ApkDelta.apply(base, patch, temporary, baseHash, targetHash, targetSize)
            verifyFile(temporary, targetHash, targetSize, expectedVersion)
            saveDownloaded(temporary, targetHash, targetSize, expectedVersion)
        } finally {
            patch.delete()
            temporary.delete()
        }
    }

    private fun saveDownloaded(temporary: File, hash: String, size: Long, expectedVersion: Long) {
        check(temporary.renameTo(apk))
        java.util.Properties().apply {
            setProperty("sha256", hash)
            setProperty("sizeBytes", size.toString())
            setProperty("versionCode", expectedVersion.toString())
            metadata.outputStream().use { store(it, null) }
        }
    }

    private fun downloadFile(address: String, destination: File, hash: String, size: Long) {
        require(hash.matches(Regex("[0-9a-fA-F]{64}")) && size in 1..MAX_APK_SIZE)
        var connection: HttpsURLConnection? = null
        try {
            var url = URL(address)
            var redirects = 0
            val started = System.nanoTime()
            val digest = MessageDigest.getInstance("SHA-256")
            while (true) {
                require(url.protocol == "https" && url.userInfo == null)
                val current = (url.openConnection() as HttpsURLConnection).apply {
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    instanceFollowRedirects = false
                    setRequestProperty("Accept-Encoding", "identity")
                }
                connection = current
                val status = current.responseCode
                if (status in listOf(301, 302, 303, 307, 308)) {
                    require(++redirects <= 5)
                    url = URL(url, requireNotNull(current.getHeaderField("Location")))
                    current.disconnect()
                    continue
                }
                require(status == 200)
                val declaredSize = current.getHeaderField("Content-Length")?.toLongOrNull() ?: -1L
                require(declaredSize == -1L || declaredSize == size)
                var received = 0L
                current.inputStream.use { input ->
                    destination.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            check(System.nanoTime() - started < 10L * 60 * 1_000_000_000)
                            val count = input.read(buffer)
                            if (count < 0) break
                            received += count
                            require(received <= size)
                            output.write(buffer, 0, count)
                            digest.update(buffer, 0, count)
                        }
                    }
                }
                require(received == size)
                break
            }
            require(digest.digest().joinToString("") { "%02x".format(it) }.equals(hash, ignoreCase = true))
        } finally {
            connection?.disconnect()
        }
    }

    private fun verifyFile(file: File, hash: String, size: Long, expectedVersion: Long) {
        require(file.isFile && file.length() == size)
        require(ApkDelta.sha256(file).equals(hash, ignoreCase = true))
        val archive = requireNotNull(activity.packageManager.getPackageArchiveInfo(file.path, signatureFlags()))
        val installed = installedPackage()
        require(archive.packageName == installed.packageName)
        require(version(archive) == expectedVersion && expectedVersion > version(installed))
        // 배포 서명 고정: 다른 키와 서명 계보의 무단 전환 방지.
        val currentSigners = signers(installed)
        if (currentSigners.isEmpty() || signers(archive) != currentSigners) throw SignatureMismatchException()
    }

    @Suppress("DEPRECATION")
    private fun installedPackage(): PackageInfo =
        activity.packageManager.getPackageInfo(activity.packageName, signatureFlags())

    @Suppress("DEPRECATION")
    private fun signatureFlags(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            info.signingInfo?.apkContentsSigners else info.signatures
        return signatures.orEmpty().map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }.toSet()
    }

    @Suppress("DEPRECATION")
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        info.longVersionCode else info.versionCode.toLong()

    fun detach() { channel.setMethodCallHandler(null) }

    private class SignatureMismatchException : Exception()

    companion object {
        // Activity 재생성 중에도 캐시 파일 변경과 설치 URI 전달 직렬화.
        private val updateInProgress = AtomicBoolean(false)
        private const val MAX_APK_SIZE = 512L * 1024 * 1024
    }
}
