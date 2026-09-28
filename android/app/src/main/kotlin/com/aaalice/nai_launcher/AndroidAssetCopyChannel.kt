package com.aaalice.nai_launcher

import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/** Streams large bundled Flutter assets into app-owned storage. */
class AndroidAssetCopyChannel(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) {
    private val executor = Executors.newSingleThreadExecutor()

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "copyAssetToPath") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val assetKey = call.argument<String>("assetKey")
            val targetPath = call.argument<String>("targetPath")
            if (assetKey !in ALLOWED_ASSETS || targetPath.isNullOrBlank()) {
                result.error("invalid_arguments", "Unsupported asset or target path.", null)
                return@setMethodCallHandler
            }

            val target = File(targetPath)
            val filesRoot = activity.filesDir.canonicalFile
            val canonicalTarget = runCatching { target.canonicalFile }.getOrElse { error ->
                result.error("invalid_target", error.message ?: "Invalid target path.", null)
                return@setMethodCallHandler
            }
            val filesPrefix = filesRoot.path + File.separator
            if (!canonicalTarget.path.startsWith(filesPrefix)) {
                result.error("invalid_target", "Target must be inside app-owned files.", null)
                return@setMethodCallHandler
            }

            executor.execute {
                runCatching {
                    canonicalTarget.parentFile?.mkdirs()
                    activity.assets.open("flutter_assets/$assetKey").use { input ->
                        FileOutputStream(canonicalTarget, false).use { output ->
                            input.copyTo(output, COPY_BUFFER_SIZE)
                            output.fd.sync()
                        }
                    }
                    canonicalTarget.length()
                }.onSuccess { length ->
                    activity.runOnUiThread { result.success(length) }
                }.onFailure { error ->
                    canonicalTarget.delete()
                    activity.runOnUiThread {
                        result.error(
                            "asset_copy_failed",
                            error.message ?: "Unable to copy bundled database.",
                            null,
                        )
                    }
                }
            }
        }
    }

    fun dispose() {
        executor.shutdown()
    }

    private companion object {
        const val CHANNEL = "com.aaalice.nai_launcher/asset_copy"
        const val COPY_BUFFER_SIZE = 64 * 1024
        val ALLOWED_ASSETS = setOf("assets/databases/tag_catalog.db")
    }
}
