package com.example.carmelitas_dormitory_system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import java.util.concurrent.TimeUnit

/** Observes settings only. Never requests GPS or writes gate/presence events. */
object LocationMonitoringHealth {
    private const val CHECK_WORK = "carmelink-location-health-check"
    private const val REPORT_WORK = "carmelink-location-health-report"
    private const val NOTICE_ID = 1003
    private var fallbackReceiver: BroadcastReceiver? = null

    fun observerFailed(context: Context, error: RuntimeException) {
        val description = "${error.javaClass.simpleName}: ${error.message}"
        Log.w("CarmeLinkHealth", "Location availability observer could not start", error)
        context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE).edit()
            .putString("monitoring_observer_error", description)
            .putLong("monitoring_observer_failed_at", System.currentTimeMillis()).apply()
    }

    @Synchronized
    private fun attachFallbackReceiver(context: Context) {
        if (fallbackReceiver != null) return
        val receiver = LocationMonitoringHealthReceiver()
        val filter = IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) addAction(LocationManager.MODE_CHANGED_ACTION)
        }
        ContextCompat.registerReceiver(context.applicationContext, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        fallbackReceiver = receiver
    }

    fun observe(context: Context) {
        if (!context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
                .getBoolean("registered", false)) return
        attachFallbackReceiver(context)
        check(context)
    }

    fun start(context: Context) {
        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("registered", false)) return
        // Keep observing while the process lives, even if foreground promotion
        // is rejected and the service has to stop.
        observe(context)
        if (!LocationHealthService.running) try {
            ContextCompat.startForegroundService(context, Intent(context, LocationHealthService::class.java))
        } catch (error: RuntimeException) {
            observerFailed(context, error)
            // Background starts can be restricted. Periodic work remains the fallback.
        }
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            CHECK_WORK, ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<LocationMonitoringHealthCheckWorker>(15, TimeUnit.MINUTES).build(),
        )
    }

    @Synchronized
    fun stop(context: Context) {
        fallbackReceiver?.let { context.applicationContext.unregisterReceiver(it) }
        fallbackReceiver = null
        context.stopService(Intent(context, LocationHealthService::class.java))
        WorkManager.getInstance(context).cancelUniqueWork(CHECK_WORK)
        WorkManager.getInstance(context).cancelUniqueWork(REPORT_WORK)
        context.getSystemService(NotificationManager::class.java).cancel(NOTICE_ID)
    }

    @Synchronized
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
        val activeReminder = notifications.activeNotifications.any {
            it.id == NOTICE_ID && (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                it.notification.channelId == "carmelink_location_health")
        }
        if (available) {
            notifications.cancel(NOTICE_ID)
            prefs.edit().remove("monitoring_health_last_reminder").apply()
        } else {
            val now = System.currentTimeMillis()
            val last = prefs.getLong("monitoring_health_last_reminder", 0L)
            val action = LocationReminderPolicy.decide(changed, activeReminder, last, now)
            val alert = action == LocationReminderPolicy.Action.ALERT
            // A stale cooldown must never hide the reminder entirely after a
            // process restart, dismissal, or a missed ON/OFF cycle. Restore it
            // silently within the cooldown; a confirmed new outage alerts.
            if (action != LocationReminderPolicy.Action.KEEP) {
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
                val allowed = notifications.areNotificationsEnabled() &&
                    (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
                        context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        notifications.getNotificationChannel("carmelink_location_health")?.importance != NotificationManager.IMPORTANCE_NONE)
                if (allowed) {
                    try {
                        notifications.notify(NOTICE_ID, NotificationCompat.Builder(context, "carmelink_location_health")
                            .setSmallIcon(R.drawable.ic_stat_carmelink)
                            .setContentTitle("Location monitoring is off")
                            .setContentText(if (reason == "LOCATION_SERVICES_DISABLED")
                                "Turn on Location to restore dormitory entry and exit alerts."
                                else "Allow precise location all the time to restore entry and exit alerts.")
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setContentIntent(contentIntent).setOngoing(true).setAutoCancel(false)
                            .setSilent(!alert).build())
                        if (alert) prefs.edit().putLong("monitoring_health_last_reminder", now).apply()
                        prefs.edit().remove("monitoring_health_notification_error").apply()
                    } catch (error: RuntimeException) {
                        Log.w("CarmeLinkHealth", "Could not post location reminder", error)
                        prefs.edit().putString("monitoring_health_notification_error",
                            "${error.javaClass.simpleName}: ${error.message}").apply()
                    }
                } else {
                    prefs.edit().putString("monitoring_health_notification_error", "Notifications or reminder channel disabled").apply()
                }
            }
        }
        val reportPending = !prefs.contains("monitoring_health_reported_available") ||
            prefs.getBoolean("monitoring_health_reported_available", true) != available ||
            prefs.getString("monitoring_health_reported_reason", null) != reason
        val alreadyQueued = prefs.contains("monitoring_health_queued_available") &&
            prefs.getBoolean("monitoring_health_queued_available", true) == available &&
            prefs.getString("monitoring_health_queued_reason", null) == reason
        if (changed || (reportPending && !alreadyQueued)) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                REPORT_WORK, ExistingWorkPolicy.APPEND_OR_REPLACE,
                OneTimeWorkRequestBuilder<MonitoringHealthWorker>()
                    // Preserve OFF then ON reports even if both occur while offline.
                    .setInputData(Data.Builder()
                        .putString("tenant_id", prefs.getString("tenant_id", null))
                        .putBoolean("available", available).putString("reason", reason).build())
                    .apply {
                        // Older Android versions require a foreground Worker implementation.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                        }
                    }
                    .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                    .build(),
            )
            prefs.edit().putBoolean("monitoring_health_queued_available", available)
                .putString("monitoring_health_queued_reason", reason).apply()
        }
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
