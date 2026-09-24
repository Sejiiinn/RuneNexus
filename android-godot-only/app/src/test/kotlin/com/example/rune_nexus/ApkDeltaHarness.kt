package com.example.rune_nexus

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.nio.file.Files
import java.security.MessageDigest
import java.util.zip.GZIPOutputStream

/** Android 없이 실행하는 복원·손상 입력·Python 생성기 상호 운용 검증. */
fun main(args: Array<String>) {
    if (args.size == 4) {
        val base = File(args[0])
        val target = File(args[1])
        val patch = File(args[2])
        val output = File(args[3])
        ApkDelta.apply(base, patch, output, ApkDelta.sha256(base), ApkDelta.sha256(target), target.length())
        check(ApkDelta.sha256(output) == ApkDelta.sha256(target))
        println("Python/Kotlin delta interoperability passed")
        return
    }
    val directory = Files.createTempDirectory("apk-delta-tests").toFile()
    try {
        val base = File(directory, "base.apk").apply { writeBytes("abcdefgh".toByteArray()) }
        val target = "abcXYZgh".toByteArray()
        val targetHash = MessageDigest.getInstance("SHA-256").digest(target)
        val baseHash = ApkDelta.sha256(base)
        val targetHex = targetHash.joinToString("") { "%02x".format(it) }
        val patch = File(directory, "update.patch")
        val output = File(directory, "result.apk")
        fun body(ops: DataOutputStream.() -> Unit): ByteArray = ByteArrayOutputStream().also { bytes ->
            DataOutputStream(bytes).use {
                it.writeBytes("RNDELTA1")
                it.writeLong(base.length())
                it.writeLong(target.size.toLong())
                it.write(MessageDigest.getInstance("SHA-256").digest(base.readBytes()))
                it.write(targetHash)
                it.ops()
            }
        }.toByteArray()
        fun compressed(raw: ByteArray): ByteArray = ByteArrayOutputStream().also { bytes ->
            GZIPOutputStream(bytes).use { it.write(raw) }
        }.toByteArray()
        fun apply() = ApkDelta.apply(base, patch, output, baseHash, targetHex, target.size.toLong())
        fun invalid(name: String, raw: ByteArray) {
            patch.writeBytes(compressed(raw))
            output.writeText("stale partial file")
            check(runCatching { apply() }.isFailure) { "$name accepted" }
            check(!output.exists()) { "$name left a partial file" }
            check(base.readText() == "abcdefgh")
        }
        val valid = body {
            writeByte(0); writeLong(0); writeLong(3)
            writeByte(1); writeLong(3); writeBytes("XYZ")
            writeByte(0); writeLong(6); writeLong(2)
            writeByte(255)
        }
        patch.writeBytes(compressed(valid))
        apply()
        check(output.readBytes().contentEquals(target))
        invalid("magic", valid.copyOf().apply { this[0] = 0 })
        invalid("header truncated", valid.copyOf(24))
        invalid("COPY bounds", body { writeByte(0); writeLong(7); writeLong(8); writeByte(255) })
        invalid("COPY offset overflow", body { writeByte(0); writeLong(Long.MAX_VALUE); writeLong(8); writeByte(255) })
        invalid("unsigned size overflow", body { writeByte(1); writeLong(-1); writeByte(255) })
        invalid("zero length", body { writeByte(1); writeLong(0); writeByte(255) })
        invalid("target overflow", body { writeByte(1); writeLong(9); writeBytes("123456789"); writeByte(255) })
        invalid("truncated DATA", body { writeByte(1); writeLong(8); writeBytes("XYZ") })
        invalid("missing END", valid.copyOf(valid.size - 1))
        invalid("trailing data", valid + byteArrayOf(0))
        invalid("wrong output hash", body { writeByte(0); writeLong(0); writeLong(8); writeByte(255) })
        invalid("unknown operation", body { writeByte(2); writeByte(255) })
        invalid("early END", body { writeByte(255) })
        invalid("base hash mismatch", valid.copyOf().apply { this[24] = (this[24].toInt() xor 1).toByte() })
        patch.writeBytes(compressed(valid).dropLast(4).toByteArray())
        check(runCatching { apply() }.isFailure && !output.exists())
        patch.writeBytes(compressed(valid))
        check(runCatching { ApkDelta.apply(base, patch, base, baseHash, targetHex, target.size.toLong()) }.isFailure)
        check(base.readText() == "abcdefgh")
        val excessiveOperations = body {
            repeat(100_001) { writeByte(0); writeLong(0); writeLong(1) }
            writeByte(255)
        }.apply { java.nio.ByteBuffer.wrap(this).putLong(16, 100_001L) }
        patch.writeBytes(compressed(excessiveOperations))
        check(runCatching { ApkDelta.apply(base, patch, output, baseHash, targetHex, 100_001L) }.isFailure)
        check(!output.exists())
        println("18 APK delta reconstruction and rejection checks passed")
    } finally {
        directory.deleteRecursively()
    }
}
