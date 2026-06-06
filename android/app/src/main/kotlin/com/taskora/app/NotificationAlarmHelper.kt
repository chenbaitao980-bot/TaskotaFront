package com.taskora.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AlarmManager 调度助手。
 * 优先使用 setAlarmClock()，失败时降级到 setAndAllowWhileIdle()。
 * 这是 Android 上进程被杀后最可靠的定时方案。
 */
object NotificationAlarmHelper {

    private const val TAG = "TaskoraAlarm"

    /**
     * 通过 AlarmManager.setAlarmClock() 调度一条通知（进程被杀后仍能触发）。
     * 若 SCHEDULE_EXACT_ALARM 未授权，自动降级到 setAndAllowWhileIdle()。
     */
    fun scheduleNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        scheduledAtMillis: Long
    ) {
        val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
            putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_ID, id)
            putExtra(NotificationAlarmReceiver.EXTRA_TITLE, title)
            putExtra(NotificationAlarmReceiver.EXTRA_BODY, body)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent, flags
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // 优先尝试 setAlarmClock（不受 Doze 影响，进程被杀后仍能触发）
        // 失败时降级到 setAndAllowWhileIdle（精度略低，但无需额外权限）
        try {
            val info = AlarmManager.AlarmClockInfo(scheduledAtMillis, pendingIntent)
            alarmManager.setAlarmClock(info, pendingIntent)
            Log.d(TAG, "scheduleNotification OK (setAlarmClock) id=$id at=$scheduledAtMillis")
        } catch (se: SecurityException) {
            // Android 12+: SCHEDULE_EXACT_ALARM 未授权时抛出 SecurityException
            // 降级到 setAndAllowWhileIdle，兼容性更广，进程被杀后在大多数设备仍可触发
            Log.w(TAG, "setAlarmClock denied (SCHEDULE_EXACT_ALARM not granted), fallback to setAndAllowWhileIdle id=$id", se)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, scheduledAtMillis, pendingIntent
                    )
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, scheduledAtMillis, pendingIntent)
                }
                Log.d(TAG, "scheduleNotification OK (setAndAllowWhileIdle fallback) id=$id")
            } catch (e: Exception) {
                Log.e(TAG, "scheduleNotification FAILED all modes id=$id", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "scheduleNotification FAILED id=$id", e)
        }
    }

    /**
     * 取消已调度的通知。
     */
    fun cancelNotification(context: Context, id: Int) {
        val intent = Intent(context, NotificationAlarmReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent, flags
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        Log.d(TAG, "cancelNotification id=$id")
    }
}
