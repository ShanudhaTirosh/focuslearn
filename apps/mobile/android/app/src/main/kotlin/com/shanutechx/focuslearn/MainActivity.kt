package com.shanutechx.focuslearn

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shanutechx.focuslearn/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val timestampUtc = call.argument<Long>("timestampUtc") ?: 0L
                    val title = call.argument<String>("title") ?: "Reminder"
                    val body = call.argument<String>("body") ?: "Upcoming class"

                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val intent = Intent(this, AlarmReceiver::class.java).apply {
                        putExtra("id", id)
                        putExtra("title", title)
                        putExtra("body", body)
                    }

                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampUtc, pendingIntent)
                        } else {
                            alarmManager.setExact(AlarmManager.RTC_WAKEUP, timestampUtc, pendingIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val intent = Intent(this, AlarmReceiver::class.java)
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
                    alarmManager.cancel(pendingIntent)
                    result.success(true)
                }
                "checkUsagePermission" -> {
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                    val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
                    } else {
                        @Suppress("DEPRECATION")
                        appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
                    }
                    result.success(mode == AppOpsManager.MODE_ALLOWED)
                }
                "openUsageSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "getInstalledApps" -> {
                    val pm = packageManager
                    val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                        addCategory(Intent.CATEGORY_LAUNCHER)
                    }
                    val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
                    val apps = resolveInfos.map {
                        mapOf(
                            "name" to it.loadLabel(pm).toString(),
                            "packageName" to it.activityInfo.packageName
                        )
                    }
                    result.success(apps)
                }
                else -> result.notImplemented()
            }
        }
    }
}
