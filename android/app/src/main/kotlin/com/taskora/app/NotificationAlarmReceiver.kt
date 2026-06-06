package com.taskora.app

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * 原生 AlarmManager 广播接收器。
 * 当 AlarmManager.setAlarmClock() 触发时，由系统拉起此 Receiver，
 * 即使 App 进程已被杀死也能正常弹出通知。
 */
class NotificationAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "taskora_reminders"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "提醒"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 创建通知通道（如果尚未创建）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                CHANNEL_ID,
                "任务提醒",        // 中文名称，系统设置中可见
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "任务与日程提醒通知"
                enableVibration(true)
                // 使用系统默认通知音效
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                        .build()
                )
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 点击通知打开 App
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_id", notificationId.toString())
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context, notificationId, tapIntent, flags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapPendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL) // 系统默认声音 + 振动 + 灯
            .build()

        notificationManager.notify(notificationId, notification)
    }
}
