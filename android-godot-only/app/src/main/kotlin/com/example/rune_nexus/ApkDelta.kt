package com.example.rune_nexus

import java.io.DataInputStream
import java.io.File
import java.io.RandomAccessFile
import java.security.MessageDigest
import java.util.zip.GZIPInputStream

/** 원본 APK를 수정하지 않는 RNDELTA1 스트리밍 복원기. */
object ApkDelta {
    const val MAX_SIZE = 512L * 1024 * 1024

    fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun apply(base: File, patch: File, output: File, baseHash: String, targetHash: String, targetSize: Long) {
        // 정규화 경로 비교: 검증 실패 정리 시 입력 파일 삭제 방지.
        require(output.canonicalFile != base.canonicalFile && output.canonicalFile != patch.canonicalFile)
        try {
            require(targetSize in 1..MAX_SIZE && base.length() in 1..MAX_SIZE && patch.length() in 1..MAX_SIZE)
            require(baseHash.matches(Regex("[0-9a-fA-F]{64}")) && targetHash.matches(Regex("[0-9a-fA-F]{64}")))
            require(sha256(base).equals(baseHash, ignoreCase = true))
            DataInputStream(GZIPInputStream(patch.inputStream().buffered())).use { input ->
                val magic = ByteArray(8).also { input.readFully(it) }
                require(magic.contentEquals("RNDELTA1".toByteArray(Charsets.US_ASCII)))
                val baseSize = input.readLong()
                val declaredTargetSize = input.readLong()
                require(baseSize == base.length() && declaredTargetSize == targetSize)
                val declaredBaseHash = ByteArray(32).also { input.readFully(it) }
                val declaredTargetHash = ByteArray(32).also { input.readFully(it) }
                require(declaredBaseHash.joinToString("") { "%02x".format(it) }.equals(baseHash, ignoreCase = true))
                require(declaredTargetHash.joinToString("") { "%02x".format(it) }.equals(targetHash, ignoreCase = true))
                var written = 0L
                var operations = 0
                val buffer = ByteArray(64 * 1024)
                RandomAccessFile(base, "r").use { source ->
                    output.outputStream().buffered().use { destination ->
                        while (true) {
                            val operation = input.readUnsignedByte()
                            if (operation == 255) {
                                require(written == targetSize && input.read() == -1)
                                break
                            }
                            require(++operations <= 100_000)
                            require(operation == 0 || operation == 1)
                            val offset = if (operation == 0) input.readLong() else 0L
                            val length = input.readLong()
                            // 뺄셈 기반 경계 검사: 부호 없는 64비트 값과 덧셈 오버플로 거부.
                            require(length > 0 && length <= targetSize - written)
                            if (operation == 0) {
                                require(offset >= 0 && offset <= baseSize && length <= baseSize - offset)
                                source.seek(offset)
                            }
                            var remaining = length
                            while (remaining > 0) {
                                val count = minOf(remaining, buffer.size.toLong()).toInt()
                                if (operation == 0) source.readFully(buffer, 0, count)
                                else input.readFully(buffer, 0, count)
                                destination.write(buffer, 0, count)
                                remaining -= count
                            }
                            written += length
                        }
                    }
                }
            }
            require(output.length() == targetSize && sha256(output).equals(targetHash, ignoreCase = true))
        } catch (error: Exception) {
            output.delete()
            throw error
        }
    }
}
