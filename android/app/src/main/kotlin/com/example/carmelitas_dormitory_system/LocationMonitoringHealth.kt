package com.example.carmelitas_dormitory_system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import java.util.concurrent.TimeUnit

/** Observes settings only. Never requests GPS or writes gate/presence events. */
object LocationMonitoringHealth {
    private const val CHECK_WORK = "carmelink-location-health-check"
    private const val REPORT_WORK = "carmelink-location-health-report"
    private const val NOTICE_ID = 1003

    fun start(context: Context) {
        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("registered", false)) return
        check(context)
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            CHECK_WORK, ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<LocationMonitoringHealthCheckWorker>(15, TimeUnit.MINUTES).build(),
        )
    }

    fun stop(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(CHECK_WORK)
        WorkManager.getInstance(context).cancelUniqueWork(REPORT_WORK)
        context.getSystemService(NotificationManager::class.java).cancel(NOTICE_ID)
    }

    fun check(context: Context) {
        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("registered", false)) return
        val location = context.getSystemService(LocationManager::class.java)
        val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) location.isLocationEnabled
            else location.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                location.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        val reason = when {
            !enabled -> "LOCATION_SERVICES_DISABLED"
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) !=
                PackageManager.PERMISSION_GRANTED -> "LOCATION_PERMISSION_DENIED"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
                PackageManager.PERMISSION_GRANTED -> "BACKGROUND_LOCATION_DENIED"
            else -> null
        }
        val available = reason == null
        val changed = !prefs.contains("monitoring_health_available") ||
            prefs.getBoolean("monitoring_health_available", true) != available ||
            prefs.getString("monitoring_health_reason", null) != reason
        prefs.edit().putBoolean("monitoring_health_available", available)
            .putString("monitoring_health_reason", reason).apply()
        val notifications = context.getSystemService(NotificationManager::class.java)
        if (available) {
            notifications.cancel(NOTICE_ID)
            prefs.edit().remove("monitoring_health_last_reminder").apply()
        } else {
            val now = System.currentTimeMillis()
            val last = prefs.getLong("monitoring_health_last_reminder", 0L)
            if (changed || now - last >= TimeUnit.HOURS.toMillis(1)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    notifications.createNotificationChannel(NotificationChannel(
                        "carmelink_location_health", "Location monitoring reminders", NotificationManager.IMPORTANCE_HIGH,
                    ))
                }
                val settings = Intent(if (reason == "LOCATION_SERVICES_DISABLED")
                    Settings.ACTION_LOCATION_SOURCE_SETTINGS else Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                if (reason != "LOCATION_SERVICES_DISABLED") {
                    settings.data = android.net.Uri.parse("package:${context.packageName}")
                }
                val contentIntent = PendingIntent.getActivity(context, NOTICE_ID, settings,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val allowed = Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
                    context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                if (allowed) {
                    notifications.notify(NOTICE_ID, NotificationCompat.Builder(context, "carmelink_location_health")
                        .setSmallIcon(R.drawable.ic_stat_carmelink)
                        .setContentTitle("Location monitoring is off")
                        .setContentText(if (reason == "LOCATION_SERVICES_DISABLED")
                            "Turn on Location to restore dormitory entry and exit alerts."
                            else "Allow precise location all the time to restore entry and exit alerts.")
                        .setContentIntent(contentIntent).setAutoCancel(true).build())
                    prefs.edit().putLong("monitoring_health_last_reminder", now).apply()
                }
            }
        }
        val reportPending = !prefs.contains("monitoring_health_reported_available") ||
            prefs.getBoolean("monitoring_health_reported_available", true) != available ||
            prefs.getString("monitoring_health_reported_reason", null) != reason
        if (changed || reportPending) WorkManager.getInstance(context).enqueueUniqueWork(
            REPORT_WORK, ExistingWorkPolicy.APPEND_OR_REPLACE,
            OneTimeWorkRequestBuilder<MonitoringHealthWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build(),
        )
    }
}

class LocationMonitoringHealthReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        LocationMonitoringHealth.check(context.applicationContext)
    }
}

class LocationMonitoringHealthCheckWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        LocationMonitoringHealth.check(applicationContext)
        return Result.success()
    }
}
