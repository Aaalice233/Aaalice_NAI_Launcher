package com.aaalice.nai_launcher

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

class AndroidAppInstaller(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var pendingApk: File? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> installApk(call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error(
                "install_in_progress",
                "Another Android package installation request is active",
                null,
            )
            return
        }
        if (path.isNullOrBlank()) {
            result.error("invalid_arguments", "APK path is required", null)
            return
        }

        val apk = try {
            File(path).canonicalFile
        } catch (error: Exception) {
            result.error("invalid_path", "Unable to resolve the APK path", error.message)
            return
        }
        val updateRoot = File(activity.cacheDir, UPDATE_DIRECTORY).canonicalFile
        val isInsideUpdateRoot =
            apk.path.startsWith(updateRoot.path + File.separator)
        if (!isInsideUpdateRoot || !apk.name.endsWith(".apk", ignoreCase = true)) {
            result.error(
                "invalid_path",
                "APK must be inside the application's verified update cache",
                null,
            )
            return
        }
        if (!apk.isFile || !apk.canRead()) {
            result.error("missing_apk", "The verified APK is no longer available", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()
        ) {
            pendingApk = apk
            pendingResult = result
            try {
                activity.startActivityForResult(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                    REQUEST_UNKNOWN_SOURCES,
                )
            } catch (error: ActivityNotFoundException) {
                clearPending()
                result.error(
                    "install_permission_unavailable",
                    "Android cannot open the unknown-apps permission screen",
                    error.message,
                )
            }
            return
        }

        launchPackageInstaller(apk, result)
    }

    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_UNKNOWN_SOURCES) return false

        val apk = pendingApk
        val result = pendingResult
        clearPending()
        if (apk == null || result == null) return true

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()
        ) {
            result.error(
                "install_permission_denied",
                "Allow this app to install unknown apps before installing the update",
                null,
            )
            return true
        }

        launchPackageInstaller(apk, result)
        return true
    }

    private fun launchPackageInstaller(apk: File, result: MethodChannel.Result) {
        try {
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.update_file_provider",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK_MIME_TYPE)
                clipData = ClipData.newRawUri("verified_update", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            activity.packageManager
                .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                .forEach { resolved ->
                    activity.grantUriPermission(
                        resolved.activityInfo.packageName,
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                }
            activity.startActivity(intent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            result.error(
                "installer_unavailable",
                "No Android package installer is available",
                error.message,
            )
        } catch (error: Exception) {
            result.error(
                "installer_launch_failed",
                "Unable to open the Android package installer",
                error.message,
            )
        }
    }

    private fun clearPending() {
        pendingApk = null
        pendingResult = null
    }

    fun dispose() {
        pendingResult?.error(
            "activity_destroyed",
            "The Android activity closed before installation could continue",
            null,
        )
        clearPending()
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL_NAME = "com.aaalice.nai_launcher/app_installer"
        const val UPDATE_DIRECTORY = "nai_launcher_updates"
        const val REQUEST_UNKNOWN_SOURCES = 7302
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
