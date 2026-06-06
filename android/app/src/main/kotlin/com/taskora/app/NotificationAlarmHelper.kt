package com.taskora.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * AlarmManager 调度助手。
 * 使用 setAlarmClock()，这是 Android 上进程被杀后最可靠的定时方案。
 */
object NotificationAlarmHelper {

    /**
     * 通过 AlarmManager.setAlarmClock() 调度一条通知。
     * App 进程被杀死后仍能准时触发。
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

        // setAlarmClock 是 Android 上最可靠的定时方式：
        // - 不受 Doze 模式影响
        // - 进程被杀死也能恢复
        // - 系统会显示闹钟图标表明有定时任务
        val info = AlarmManager.AlarmClockInfo(scheduledAtMillis, pendingIntent)
        alarmManager.setAlarmClock(info, pendingIntent)
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
    }
}
