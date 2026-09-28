package com.aaalice.nai_launcher

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class AgentQuestionNotifications(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) {
    private val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE)
        as NotificationManager
    private val channel = MethodChannel(messenger, "com.aaalice.nai_launcher/agent_questions")

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "show" -> {
                        show(
                            requireNotNull(call.argument<String>("requestId")),
                            requireNotNull(call.argument<String>("title")),
                            requireNotNull(call.argument<String>("message")),
                            requireNotNull(call.argument<Number>("expiresAt")).toLong(),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        manager.cancel(NOTIFICATION_ID)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("agent_question_notification_failed", error.toString(), null)
            }
        }
    }

    private fun show(requestId: String, title: String, message: String, expiresAt: Long) {
        check(manager.areNotificationsEnabled()) { "Notifications are disabled" }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, title, NotificationManager.IMPORTANCE_HIGH,
            ))
            check(manager.getNotificationChannel(CHANNEL_ID).importance !=
                NotificationManager.IMPORTANCE_NONE) { "Question channel is disabled" }
        }
        val intent = Intent(activity, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(REQUEST_ID, requestId)
        val contentIntent = PendingIntent.getActivity(
            activity, NOTIFICATION_ID, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(activity, CHANNEL_ID)
                .setTimeoutAfter((expiresAt - System.currentTimeMillis()).coerceAtLeast(1))
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(activity).setPriority(Notification.PRIORITY_HIGH)
        }
        manager.notify(NOTIFICATION_ID, builder
            .setSmallIcon(R.drawable.ic_agent_question_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .build())
    }

    fun onNewIntent(intent: Intent) {
        val requestId = intent.getStringExtra(REQUEST_ID) ?: return
        intent.removeExtra(REQUEST_ID)
        channel.invokeMethod("open", requestId)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        manager.cancel(NOTIFICATION_ID)
    }

    private companion object {
        const val CHANNEL_ID = "agent_questions"
        const val NOTIFICATION_ID = 4102
        const val REQUEST_ID = "agent_question_request_id"
    }
}
