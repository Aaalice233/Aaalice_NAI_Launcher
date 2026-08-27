package com.aaalice.nai_launcher

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

/** Streams app-generated files into Android's Storage Access Framework. */
class AndroidFileExportChannel(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) {
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveSourcePath: String? = null
    private var pendingDirectoryResult: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFileFromPath" -> startSaveFile(call, result)
                "pickExportDirectory" -> startPickDirectory(result)
                "writeFileToDirectory" -> writeFileToDirectory(call, result)
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            SAVE_DOCUMENT_REQUEST_CODE -> {
                completeSaveFile(resultCode, data)
                true
            }
            PICK_DIRECTORY_REQUEST_CODE -> {
                completePickDirectory(resultCode, data)
                true
            }
            else -> false
        }
    }

    fun saveImageToPictures(
        sourcePath: String,
        displayName: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        val source = File(sourcePath)
        val fileName = sanitizeFileName(displayName)
        if (!source.isFile || fileName == null) {
            result.error(
                "invalid_arguments",
                "A readable sourcePath and displayName are required.",
                null,
            )
            return
        }

        executor.execute {
            runCatching { publishImage(source, fileName, mimeType) }
                .onSuccess { outputUri ->
                    activity.runOnUiThread { result.success(outputUri.toString()) }
                }.onFailure { error ->
                    activity.runOnUiThread {
                        result.error(
                            "media_store_write_failed",
                            error.message ?: "Unable to save the image.",
                            null,
                        )
                    }
                }
        }
    }

    fun dispose() {
        pendingSaveResult?.error(
            "activity_destroyed",
            "The export activity was destroyed before the file was saved.",
            null,
        )
        pendingDirectoryResult?.error(
            "activity_destroyed",
            "The export activity was destroyed before a folder was selected.",
            null,
        )
        clearPendingSave()
        pendingDirectoryResult = null
        executor.shutdown()
    }

    private fun startSaveFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingDirectoryResult != null) {
            result.error("export_in_progress", "Another Android export picker is open.", null)
            return
        }

        val sourcePath = call.argument<String>("sourcePath")
        val fileName = sanitizeFileName(call.argument<String>("fileName"))
        val mimeType = call.argument<String>("mimeType")?.takeIf { it.isNotBlank() }
            ?: "application/octet-stream"
        if (sourcePath.isNullOrBlank() || fileName == null || !File(sourcePath).isFile) {
            result.error("invalid_arguments", "A readable sourcePath and fileName are required.", null)
            return
        }

        pendingSaveResult = result
        pendingSaveSourcePath = sourcePath
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            activity.startActivityForResult(intent, SAVE_DOCUMENT_REQUEST_CODE)
        } catch (error: Throwable) {
            clearPendingSave()
            result.error("save_picker_failed", error.message ?: "Unable to open the save picker.", null)
        }
    }

    private fun startPickDirectory(result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingDirectoryResult != null) {
            result.error("export_in_progress", "Another Android export picker is open.", null)
            return
        }

        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        try {
            activity.startActivityForResult(intent, PICK_DIRECTORY_REQUEST_CODE)
        } catch (error: Throwable) {
            pendingDirectoryResult = null
            result.error(
                "directory_picker_failed",
                error.message ?: "Unable to open the folder picker.",
                null,
            )
        }
    }

    private fun completeSaveFile(resultCode: Int, data: Intent?) {
        val result = pendingSaveResult ?: return
        val sourcePath = pendingSaveSourcePath
        clearPendingSave()

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val outputUri = data?.data
        if (sourcePath == null || outputUri == null) {
            result.error("save_destination_missing", "Android returned no save destination.", null)
            return
        }

        executor.execute {
            runCatching { copyFileToUri(sourcePath, outputUri) }
                .onSuccess { activity.runOnUiThread { result.success(outputUri.toString()) } }
                .onFailure { error ->
                    activity.runOnUiThread {
                        result.error(
                            "file_export_failed",
                            error.message ?: "Unable to export the file.",
                            null,
                        )
                    }
                }
        }
    }

    private fun completePickDirectory(resultCode: Int, data: Intent?) {
        val result = pendingDirectoryResult ?: return
        pendingDirectoryResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val treeUri = data?.data
        if (treeUri == null) {
            result.error("directory_missing", "Android returned no export folder.", null)
            return
        }
        val grantedFlags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        if (grantedFlags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) {
            result.error(
                "directory_not_writable",
                "The selected folder did not grant write access.",
                null,
            )
            return
        }

        // Some document providers grant usable session access but do not
        // implement persistent grants. The selected URI is only used by the
        // active export operation, so that provider limitation is not fatal.
        if (data.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0) {
            runCatching {
                activity.contentResolver.takePersistableUriPermission(treeUri, grantedFlags)
            }
        }
        result.success(treeUri.toString())
    }

    private fun writeFileToDirectory(call: MethodCall, result: MethodChannel.Result) {
        val treeUriText = call.argument<String>("directoryUri")
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = sanitizeFileName(call.argument<String>("fileName"))
        val mimeType = call.argument<String>("mimeType")?.takeIf { it.isNotBlank() }
            ?: "application/octet-stream"
        if (
            treeUriText.isNullOrBlank() ||
            sourcePath.isNullOrBlank() ||
            fileName == null ||
            !File(sourcePath).isFile
        ) {
            result.error(
                "invalid_arguments",
                "directoryUri, a readable sourcePath, and fileName are required.",
                null,
            )
            return
        }

        executor.execute {
            runCatching {
                createAndWriteDocument(
                    treeUri = Uri.parse(treeUriText),
                    sourcePath = sourcePath,
                    fileName = fileName,
                    mimeType = mimeType,
                )
            }.onSuccess { outputUri ->
                activity.runOnUiThread { result.success(outputUri.toString()) }
            }.onFailure { error ->
                activity.runOnUiThread {
                    result.error(
                        "directory_export_failed",
                        error.message ?: "Unable to export the file to the selected folder.",
                        null,
                    )
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun publishImage(source: File, fileName: String, mimeType: String): Uri {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Aaalice NAI Launcher",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            } else {
                val directory = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                    "Aaalice NAI Launcher",
                )
                check(directory.exists() || directory.mkdirs()) {
                    "Unable to create the Pictures directory."
                }
                put(MediaStore.Images.Media.DATA, uniqueFile(directory, fileName).absolutePath)
            }
        }

        val outputUri = checkNotNull(
            activity.contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values,
            ),
        ) { "MediaStore refused the image." }

        try {
            copyFileToUri(source.path, outputUri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                activity.contentResolver.update(
                    outputUri,
                    ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 0)
                    },
                    null,
                    null,
                )
            }
            return outputUri
        } catch (error: Throwable) {
            activity.contentResolver.delete(outputUri, null, null)
            throw error
        }
    }

    private fun uniqueFile(directory: File, fileName: String): File {
        val requested = File(directory, fileName)
        if (!requested.exists()) return requested

        val extensionIndex = fileName.lastIndexOf('.')
        val baseName = if (extensionIndex > 0) fileName.substring(0, extensionIndex) else fileName
        val extension = if (extensionIndex > 0) fileName.substring(extensionIndex) else ""
        var suffix = 1
        var candidate: File
        do {
            candidate = File(directory, "$baseName ($suffix)$extension")
            suffix += 1
        } while (candidate.exists())
        return candidate
    }

    private fun createAndWriteDocument(
        treeUri: Uri,
        sourcePath: String,
        fileName: String,
        mimeType: String,
    ): Uri {
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        val outputUri = checkNotNull(
            DocumentsContract.createDocument(
                activity.contentResolver,
                parentUri,
                mimeType,
                fileName,
            ),
        ) { "The selected document provider refused the file." }

        try {
            copyFileToUri(sourcePath, outputUri)
            return outputUri
        } catch (error: Throwable) {
            runCatching { DocumentsContract.deleteDocument(activity.contentResolver, outputUri) }
            throw error
        }
    }

    private fun copyFileToUri(sourcePath: String, outputUri: Uri) {
        FileInputStream(File(sourcePath)).use { input ->
            activity.contentResolver.openOutputStream(outputUri, "w")?.use { output ->
                input.copyTo(output, DEFAULT_BUFFER_SIZE)
                output.flush()
            } ?: error("Unable to open the Android document output stream.")
        }
    }

    private fun clearPendingSave() {
        pendingSaveResult = null
        pendingSaveSourcePath = null
    }

    private fun sanitizeFileName(value: String?): String? {
        val sanitized = value
            ?.replace(Regex("[\\u0000-\\u001f/\\\\]"), "_")
            ?.trim()
        return sanitized?.takeIf { it.isNotEmpty() && it != "." && it != ".." }
    }

    private companion object {
        const val CHANNEL = "com.aaalice.nai_launcher/file_export"
        const val SAVE_DOCUMENT_REQUEST_CODE = 49101
        const val PICK_DIRECTORY_REQUEST_CODE = 49102
    }
}
