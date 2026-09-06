package com.aaalice.nai_launcher

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var questionNotifications: AgentQuestionNotifications? = null
    private var appInstaller: AndroidAppInstaller? = null
    private var assetCopyChannel: AndroidAssetCopyChannel? = null
    private var fileExportChannel: AndroidFileExportChannel? = null
    private var generationServiceChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        questionNotifications = AgentQuestionNotifications(this, flutterEngine.dartExecutor.binaryMessenger)
        fileExportChannel = AndroidFileExportChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        assetCopyChannel = AndroidAssetCopyChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        appInstaller = AndroidAppInstaller(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        generationServiceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GENERATION_SERVICE_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                try {
                    val serviceIntent = Intent(
                        this@MainActivity,
                        GenerationForegroundService::class.java,
                    )
                    when (call.method) {
                        "start" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            result.success(null)
                        }
                        "stop" -> {
                            stopService(serviceIntent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "generation_service_failed",
                        error.message ?: "Unable to update generation service",
                        null,
                    )
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageFromPath" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"
                    if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                        result.error(
                            "invalid_arguments",
                            "sourcePath and fileName are required",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    fileExportChannel?.saveImageToPictures(
                        sourcePath = sourcePath,
                        displayName = fileName,
                        mimeType = mimeType,
                        result = result,
                    ) ?: result.error(
                        "export_unavailable",
                        "Android file exporter is unavailable",
                        null,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (appInstaller?.onActivityResult(requestCode) == true) return
        fileExportChannel?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        questionNotifications?.onNewIntent(intent)
    }

    override fun onDestroy() {
        questionNotifications?.dispose()
        questionNotifications = null
        appInstaller?.dispose()
        appInstaller = null
        assetCopyChannel?.dispose()
        assetCopyChannel = null
        fileExportChannel?.dispose()
        fileExportChannel = null
        generationServiceChannel?.setMethodCallHandler(null)
        generationServiceChannel = null
        super.onDestroy()
    }

    private companion object {
        const val MEDIA_CHANNEL = "com.aaalice.nai_launcher/media_store"
        const val GENERATION_SERVICE_CHANNEL =
            "com.aaalice.nai_launcher/generation_service"
    }
}
