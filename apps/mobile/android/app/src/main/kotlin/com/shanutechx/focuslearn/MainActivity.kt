package com.shanutechx.focuslearn

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
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
                        val prefs = getSharedPreferences("focuslearn_alarms", Context.MODE_PRIVATE)
                        prefs.edit().putString("alarm_$id", "$id|$timestampUtc|$title|$body").apply()
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
                    val prefs = getSharedPreferences("focuslearn_alarms", Context.MODE_PRIVATE)
                    prefs.edit().remove("alarm_$id").apply()
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
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
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PackageManager.MATCH_ALL
                    } else {
                        0
                    }
                    val resolveInfos = pm.queryIntentActivities(mainIntent, flags)
                    val apps = resolveInfos.map {
                        mapOf(
                            "name" to it.loadLabel(pm).toString(),
                            "packageName" to it.activityInfo.packageName
                        )
                    }
                    result.success(apps)
                }
                "getBatteryStatus" -> {
                    val ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                    val batteryStatus: Intent? = registerReceiver(null, ifilter)
                    val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                    val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                    val batteryPct = if (level != -1 && scale != -1) (level * 100 / scale.toFloat()).toInt() else 100
                    val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                    val isCharging: Boolean = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                            status == BatteryManager.BATTERY_STATUS_FULL
                    result.success(mapOf("level" to batteryPct, "isCharging" to isCharging))
                }
                "getNetworkType" -> {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    var netType = "none"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val network = cm.activeNetwork
                        val capabilities = cm.getNetworkCapabilities(network)
                        if (capabilities != null) {
                            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                netType = "wifi"
                            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                                netType = "cellular"
                            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                                netType = "ethernet"
                            }
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        val activeInfo = cm.activeNetworkInfo
                        if (activeInfo != null && activeInfo.isConnected) {
                            netType = if (activeInfo.type == ConnectivityManager.TYPE_WIFI) "wifi" else "cellular"
                        }
                    }
                    result.success(netType)
                }
                "getAppUsageSummary" -> {
                    val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                    val startTime = call.argument<Long>("startTime") ?: (System.currentTimeMillis() - 86400000L)
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                    val pm = packageManager
                    val list = mutableListOf<Map<String, Any>>()
                    for (usage in stats) {
                        if (usage.totalTimeInForeground > 60000L) { // at least 1 minute
                            val appName = try {
                                val info = pm.getApplicationInfo(usage.packageName, 0)
                                pm.getApplicationLabel(info).toString()
                            } catch (_: Exception) {
                                usage.packageName
                            }
                            list.add(mapOf(
                                "packageName" to usage.packageName,
                                "appLabel" to appName,
                                "minutes" to (usage.totalTimeInForeground / 60000L).toInt()
                            ))
                        }
                    }
                    result.success(list)
                }
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "getForegroundPackage" -> {
                    val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                    val time = System.currentTimeMillis()
                    val events = usm.queryEvents(time - 1000 * 15, time)
                    var foregroundApp: String? = null
                    val event = UsageEvents.Event()
                    while (events.hasNextEvent()) {
                        events.getNextEvent(event)
                        if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && event.eventType == UsageEvents.Event.ACTIVITY_MOVED_TO_FOREGROUND)) {
                            foregroundApp = event.packageName
                        }
                    }
                    result.success(foregroundApp)
                }
                "bringAppToFront" -> {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    }
                    var launched = false
                    if (intent != null) {
                        try {
                            startActivity(intent)
                            launched = true
                        } catch (_: Exception) {
                            launched = false
                        }
                    }
                    if (!launched) {
                        // Fallback: post high-priority heads-up notification with pending intent
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = android.app.NotificationChannel(
                                "focuslearn_enforcement",
                                "Focus Enforcement Alerts",
                                android.app.NotificationManager.IMPORTANCE_HIGH
                            )
                            notificationManager.createNotificationChannel(channel)
                        }
                        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                        val pendingIntent = PendingIntent.getActivity(
                            this,
                            9999,
                            intent ?: packageManager.getLaunchIntentForPackage(packageName),
                            pendingFlags
                        )
                        val notification = androidx.core.app.NotificationCompat.Builder(this, "focuslearn_enforcement")
                            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                            .setContentTitle("Focus Session Active")
                            .setContentText("Tap to return to Focus Learn and keep your session streak.")
                            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MAX)
                            .setCategory(androidx.core.app.NotificationCompat.CATEGORY_ALARM)
                            .setFullScreenIntent(pendingIntent, true)
                            .setContentIntent(pendingIntent)
                            .setAutoCancel(true)
                            .build()
                        notificationManager.notify(9999, notification)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
