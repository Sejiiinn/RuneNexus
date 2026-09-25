package com.example.rune_nexus

import java.io.ByteArrayInputStream
import java.io.File
import java.io.InputStream
import java.net.URL
import java.net.URLConnection
import java.net.URLStreamHandler
import java.nio.file.Files
import java.security.MessageDigest
import java.security.cert.Certificate
import javax.net.ssl.HttpsURLConnection
import sun.misc.Unsafe

/** JVM harness of the actual downloader; no Activity, installer, or user data is accessed. */
fun main() {
    var payload = ByteArray(3 * 64 * 1024) { (it % 251).toByte() }
    var declaredSize = payload.size.toLong()
    var delay = 0L
    var failAfter = -1
    URL.setURLStreamHandlerFactory { protocol ->
        if (protocol != "https") null else object : URLStreamHandler() {
            override fun openConnection(url: URL): URLConnection = object : HttpsURLConnection(url) {
                override fun connect() {}
                override fun disconnect() {}
                override fun usingProxy() = false
                override fun getCipherSuite() = "test"
                override fun getLocalCertificates(): Array<Certificate>? = null
                override fun getServerCertificates(): Array<Certificate> = emptyArray()
                override fun getResponseCode() = 200
                override fun getHeaderField(name: String) = if (name == "Content-Length") declaredSize.toString() else null
                override fun getInputStream(): InputStream = object : ByteArrayInputStream(payload) {
                    override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
                        if (failAfter >= 0 && pos >= failAfter) throw java.io.IOException("interrupted transfer")
                        if (delay > 0) Thread.sleep(delay)
                        return super.read(bytes, offset, length)
                    }
                }
            }
        }
    }
    val unsafe = Unsafe::class.java.getDeclaredField("theUnsafe").apply { isAccessible = true }.get(null) as Unsafe
    val updater = unsafe.allocateInstance(AppUpdater::class.java) as AppUpdater
    val method = AppUpdater::class.java.getDeclaredMethod("downloadFile", String::class.java,
        File::class.java, String::class.java, Long::class.javaPrimitiveType, AppUpdater.Result::class.java)
        .apply { isAccessible = true }
    val events = mutableListOf<Triple<String, Long, Long>>()
    val directory = Files.createTempDirectory("update-progress-").toFile()
    val destination = File(directory, "test.part")
    val result = object : AppUpdater.Result {
        override fun success(value: Any?) {}
        override fun error(code: String, message: String) {}
        override fun progress(stage: String, receivedBytes: Long, totalBytes: Long) {
            if (stage == "download" && receivedBytes > 0) check(destination.length() == receivedBytes)
            events.add(Triple(stage, receivedBytes, totalBytes))
        }
    }
    fun hash() = MessageDigest.getInstance("SHA-256").digest(payload).joinToString("") { "%02x".format(it) }
    fun run(expectedSize: Long = declaredSize, expectedHash: String = hash(), address: String = "https://fixture.test/update"): Boolean {
        events.clear()
        destination.delete()
        return runCatching { method.invoke(updater, address, destination, expectedHash, expectedSize, result) }.isSuccess
    }
    try {
        check(run())
        check(events.first() == Triple("download", 0L, declaredSize))
        check(events.takeLast(2) == listOf(Triple("download", declaredSize, declaredSize),
            Triple("verify", declaredSize, declaredSize)))
        check(events.filter { it.first == "download" }.zipWithNext().all { (a, b) -> a.second < b.second })
        check(destination.readBytes().contentEquals(payload))
        delay = 110
        check(run())
        check(events.filter { it.first == "download" }.map { it.second } == listOf(0L, 65536L, 131072L, declaredSize))
        delay = 0
        failAfter = 65536
        check(!run())
        check(events.last() == Triple("download", 65536L, declaredSize))
        check(events.none { it.first == "verify" })
        failAfter = -1
        check(!run(expectedHash = "0".repeat(64)))
        check(events.last().first == "verify")
        check(!run(expectedSize = declaredSize + 1))
        check(events.size == 1 && !destination.exists())
        declaredSize = -1
        check(!run(expectedSize = payload.size.toLong() - 1))
        check(events.last().second == 131072L)
        check(!run(expectedSize = payload.size.toLong() + 1))
        check(events.last().second == payload.size.toLong() && events.none { it.first == "verify" })
        check(!run(expectedSize = payload.size.toLong(), address = "http://fixture.test/update"))
        check(events.size == 1 && !destination.exists())
        val cachedApk = File(directory, "update.apk").apply { writeText("damaged") }
        val cachedMetadata = File(directory, "update.properties").apply {
            writeText("versionCode=2\nsizeBytes=7\nsha256=${"0".repeat(64)}\n")
        }
        AppUpdater::class.java.getDeclaredField("apk").apply { isAccessible = true }.set(updater, cachedApk)
        AppUpdater::class.java.getDeclaredField("metadata").apply { isAccessible = true }.set(updater, cachedMetadata)
        val reuse = AppUpdater::class.java.getDeclaredMethod("reuseDownloaded", String::class.java,
            Long::class.javaPrimitiveType, Long::class.javaPrimitiveType, Long::class.javaPrimitiveType,
            AppUpdater.Result::class.java).apply { isAccessible = true }
        events.clear()
        check(reuse.invoke(updater, "0".repeat(64), 7L, 2L, 524288L, result) == false)
        check(events == listOf(Triple("verify", 0L, 524288L)))
        events.clear()
        check(reuse.invoke(updater, "0".repeat(64), 7L, 3L, 524288L, result) == false)
        check(events.isEmpty())
        println("10 downloader progress/security/cache checks passed")
    } finally {
        directory.deleteRecursively()
    }
}
