package com.aaalice.nai_launcher

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.core.content.IntentCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.ArrayDeque
import java.util.concurrent.Executors

/** Retains share grants until Flutter is ready to read each image. */
class AndroidImageShareChannel(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "com.aaalice.nai_launcher/image_share")
    private val pending = ArrayDeque<Intent>()
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "takeNext") {
                result.notImplemented()
            } else {
                val share = pending.pollFirst()
                if (share == null) {
                    result.success(null)
                } else {
                    worker.execute {
                        try {
                            val data = readShare(share)
                            main.post { result.success(data) }
                        } catch (error: Exception) {
                            android.util.Log.e("ImageShare", "Unable to read shared image", error)
                            main.post {
                                result.error("image_share_read_failed", error.message, null)
                            }
                        }
                    }
                }
            }
        }
        accept(activity.intent)
    }

    fun accept(intent: Intent) {
        if (intent.action != Intent.ACTION_SEND) return
        pending.addLast(Intent(intent))
        // The Activity's launch intent can survive engine reconfiguration.
        intent.action = null
        channel.invokeMethod("available", null)
    }

    private fun readShare(intent: Intent): Map<String, Any> {
        val clip = intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)
        val stream = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
            ?: clip?.uri?.takeIf { it.scheme == "content" }
        if (stream != null) {
            require(stream.scheme == "content") { "Shared image must use a content URI" }
            val resolver = activity.contentResolver
            val mime = resolver.getType(stream) ?: intent.type
            require(mime?.startsWith("image/") == true) { "Shared content is not an image" }
            val extension = when (mime) {
                "image/jpeg" -> "jpg"
                "image/webp" -> "webp"
                "image/gif" -> "gif"
                "image/bmp" -> "bmp"
                else -> "png"
            }
            var name = "shared-image.$extension"
            resolver.query(stream, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst() && !it.isNull(0)) name = it.getString(0)
            }
            if (name.substringAfterLast('.', "").lowercase() !in IMAGE_EXTENSIONS) {
                name = "$name.$extension"
            }
            val bytes = resolver.openInputStream(stream)?.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size().toLong() + count <= MAX_IMAGE_BYTES) {
                        "Shared image exceeds 256 MiB"
                    }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            } ?: error("Shared image stream is unavailable")
            require(bytes.isNotEmpty()) { "Shared image is empty" }
            return mapOf("fileName" to name.substringAfterLast('/'), "bytes" to bytes)
        }
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?: clip?.text?.toString()
            ?: clip?.uri?.takeIf { it.scheme == "http" || it.scheme == "https" }?.toString()
        require(!text.isNullOrBlank()) { "Share contains neither an image nor a link" }
        return mapOf("text" to text)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
        pending.clear()
    }

    private companion object {
        const val MAX_IMAGE_BYTES = 256L * 1024 * 1024
        val IMAGE_EXTENSIONS = setOf("png", "jpg", "jpeg", "webp", "gif", "bmp")
    }
}
