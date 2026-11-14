package com.shanutechx.focuslearn

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            val prefs = context.getSharedPreferences("focuslearn_alarms", Context.MODE_PRIVATE)
            val allEntries = prefs.all
            val now = System.currentTimeMillis()
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val editor = prefs.edit()

            for ((key, value) in allEntries) {
                if (key.startsWith("alarm_") && value is String) {
                    val parts = value.split("|")
                    if (parts.size >= 4) {
                        val id = parts[0].toIntOrNull() ?: continue
                        val timestampUtc = parts[1].toLongOrNull() ?: continue
                        val title = parts[2]
                        val body = parts[3]

                        if (timestampUtc > now) {
                            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                                putExtra("id", id)
                                putExtra("title", title)
                                putExtra("body", body)
                            }
                            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                            val pendingIntent = PendingIntent.getBroadcast(context, id, alarmIntent, flags)

                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    if (alarmManager.canScheduleExactAlarms()) {
                                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampUtc, pendingIntent)
                                    } else {
                                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampUtc, pendingIntent)
                                    }
                                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampUtc, pendingIntent)
                                } else {
                                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, timestampUtc, pendingIntent)
                                }
                            } catch (_: Exception) {
                                // Graceful fallback
                            }
                        } else {
                            // Purge expired alarms from storage
                            editor.remove(key)
                        }
                    }
                }
            }
            editor.apply()
        }
    }
}


