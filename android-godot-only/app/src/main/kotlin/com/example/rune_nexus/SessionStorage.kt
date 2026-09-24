package com.example.rune_nexus

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.util.AtomicFile
import java.io.File
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.BadPaddingException
import javax.crypto.IllegalBlockSizeException
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class SessionUnreadableException : GeneralSecurityException()

internal class SessionStorage(context: Context) {
    // noBackupFilesDir: 클라우드 백업 및 기기 이전에서 제외되는 자격 증명.
    private val file = AtomicFile(File(context.noBackupFilesDir, "auth_session.enc"))
    private val alias = "rune_nexus_session_v1"
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @Synchronized
    fun read(): String? {
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) {
            return null
        }
        val bytes = file.readFully()
        if (bytes.size < 1 + 12 + 16 || bytes[0] != 1.toByte()) {
            throw SessionUnreadableException()
        }
        val key = keyStore.getKey(alias, null) as? SecretKey
            ?: throw SessionUnreadableException()
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(1, 13)))
            cipher.updateAAD(alias.toByteArray(Charsets.UTF_8))
            return cipher.doFinal(bytes, 13, bytes.size - 13).toString(Charsets.UTF_8)
        } catch (_: KeyPermanentlyInvalidatedException) {
            throw SessionUnreadableException()
        } catch (_: BadPaddingException) {
            // GCM 인증 태그 불일치(AEADBadTagException 포함).
            throw SessionUnreadableException()
        } catch (_: IllegalBlockSizeException) {
            throw SessionUnreadableException()
        }
    }

    @Synchronized
    fun write(value: String) {
        val key = keyStore.getKey(alias, null) as? SecretKey ?: KeyGenerator
            .getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                init(
                    KeyGenParameterSpec.Builder(
                        alias,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build(),
                )
            }.generateKey()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(alias.toByteArray(Charsets.UTF_8))
        val encrypted = byteArrayOf(1) + cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val stream = file.startWrite()
        try {
            stream.write(encrypted)
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
    }

    @Synchronized
    fun delete() {
        file.delete()
        if (file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()) {
            throw java.io.IOException("Session removal failed")
        }
        keyStore.deleteEntry(alias)
    }
}
