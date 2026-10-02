package com.example.carmelitas_dormitory_system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Persistent, user-visible location monitor for the exact property polygon.
 * Circular geofences remain low-power recovery hints, while this service
 * handles crossings that occur inside their larger wake-up radius.
 */
class TripwireLocationBurstService : Service() {
    companion object {
        const val ACTION_START = "com.carmelita.carmelink.action.START_TRIPWIRE"
        const val ACTION_STOP = "com.carmelita.carmelink.action.STOP_TRIPWIRE"
        private const val CHANNEL_ID = "carmelink_tripwire_monitoring"
        private const val UPDATES_CHANNEL_ID = "carmelink_updates"
        private const val NOTIFICATION_ID = 9108
        private const val ENTRY_NOTIFICATION_ID = 1001
        private const val EXIT_NOTIFICATION_ID = 1002
        private const val LOCATION_OFF_NOTIFICATION_ID = 1003
        private const val HEALTH_CHECK_INTERVAL = 60_000L
        private const val REMINDER_INTERVAL = 60L * 60L * 1000L
    }

    private val locationClient by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private var running = false
    private var highAccuracyMode = false
    private val healthHandler = Handler(Looper.getMainLooper())
    private val healthCheck = object : Runnable {
        override fun run() {
            checkMonitoringHealth()
            healthHandler.postDelayed(this, HEALTH_CHECK_INTERVAL)
        }
    }
    private val providerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) = checkMonitoringHealth()
    }
    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            // A batched callback is one observation, not multiple independent
            // confirmations. Only its newest fix may advance a candidate.
            val location = result.lastLocation ?: return
            val direction = TripwireCrossingVerifier.accept(this@TripwireLocationBurstService, location)
            if (direction != null) {
                val queued = TripwireGeofenceManager.appendEvent(
                    this@TripwireLocationBurstService,
                    direction,
                    System.currentTimeMillis(),
                )
                if (queued && !MainActivity.isInForeground) {
                    CrossingNotificationHelper.show(this@TripwireLocationBurstService, direction)
                }
            }
            updateLocationMode(hasCandidateTransition())
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_carmelink)
                .setContentTitle("CarmeLink location monitoring")
                .setContentText("Dormitory boundary alerts are active")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build(),
        )
        val filter = IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) addAction(LocationManager.MODE_CHANGED_ACTION)
        }
        ContextCompat.registerReceiver(this, providerReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        healthHandler.post(healthCheck)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopMonitoring()
            return START_NOT_STICKY
        }
        if (!running) startMonitoring()
        return START_STICKY
    }

    private fun startMonitoring() {
        // Exact polygon evaluation requires accurate fixes while the tenant is
        // moving, including when the Flutter activity is no longer running.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            stopSelf()
            return
        }

        // If a geofence transition was recently detected (by GeofenceTransitionWorker
        // while the app was killed), start in high-accuracy mode immediately so
        // TripwireCrossingVerifier can confirm the crossing faster.
        val prefs = getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
        val lastTransitionAt = prefs.getLong("last_geofence_transition_at", 0L)
        val hintRecent = System.currentTimeMillis() - lastTransitionAt < 5 * 60 * 1000L
        updateLocationMode(hintRecent)
    }

    private fun locationRequest(highAccuracy: Boolean): LocationRequest = if (highAccuracy) {
        // Near an edge (or while confirming a candidate), do not require
        // movement between fixes so entry can complete after the tenant stops.
        LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5_000L)
            .setMinUpdateIntervalMillis(3_000L).setMinUpdateDistanceMeters(0f)
            .setMaxUpdateAgeMillis(5_000L).build()
    } else {
        LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 30_000L)
            .setMinUpdateIntervalMillis(15_000L).setMinUpdateDistanceMeters(10f)
            .setMaxUpdateAgeMillis(30_000L).build()
    }

    private fun updateLocationMode(highAccuracy: Boolean) {
        if (running && highAccuracyMode == highAccuracy) return
        try {
            if (running) locationClient.removeLocationUpdates(callback)
            highAccuracyMode = highAccuracy
            running = true
            locationClient.requestLocationUpdates(
                locationRequest(highAccuracy), callback, Looper.getMainLooper(),
            )
        } catch (_: SecurityException) {
            stopMonitoring()
        }
    }

    private fun hasCandidateTransition(): Boolean {
        val prefs = getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
        if (prefs.getInt("candidate_fix_count", 0) <= 0) return false
        val startedAt = prefs.getLong("candidate_started_at", 0L)
        if (startedAt > 0L && System.currentTimeMillis() - startedAt <= 120_000L) return true
        prefs.edit().remove("candidate_direction").remove("candidate_fix_count")
            .remove("candidate_started_at").apply()
        return false
    }

    private fun stopMonitoring() {
        if (running) locationClient.removeLocationUpdates(callback)
        running = false
        highAccuracyMode = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        healthHandler.removeCallbacks(healthCheck)
        try { unregisterReceiver(providerReceiver) } catch (_: IllegalArgumentException) { }
        if (running) locationClient.removeLocationUpdates(callback)
        running = false
        highAccuracyMode = false
        super.onDestroy()
    }

    private fun checkMonitoringHealth() {
        val locationManager = getSystemService(LocationManager::class.java)
        val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) locationManager.isLocationEnabled
            else locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        val hasPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val hasBackgroundPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val available = enabled && hasPermission && hasBackgroundPermission
        val reason = when {
            !enabled -> "LOCATION_SERVICES_DISABLED"
            !hasPermission -> "LOCATION_PERMISSION_DENIED"
            !hasBackgroundPermission -> "BACKGROUND_LOCATION_DENIED"
            else -> null
        }
        val prefs = getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
        val previous = prefs.getBoolean("monitoring_health_available", true)
        if (previous != available || (!available && prefs.getString("monitoring_health_reason", null) != reason)) {
            prefs.edit().putBoolean("monitoring_health_available", available)
                .putString("monitoring_health_reason", reason).apply()
            WorkManager.getInstance(this).enqueueUniqueWork(
                "carmelink-monitoring-health", ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<MonitoringHealthWorker>()
                    .setConstraints(TripwireSyncWorker.constraints).build(),
            )
            if (available) {
                getSystemService(NotificationManager::class.java)
                    .cancel(LOCATION_OFF_NOTIFICATION_ID)
                // A later outage is a new incident and must alert immediately,
                // even if recovery happened less than one hour ago.
                prefs.edit().remove("last_location_reminder_at").apply()
            }
        }
        if (!available) showLocationReminder(prefs, reason)
    }

    private fun showLocationReminder(prefs: android.content.SharedPreferences, reason: String?) {
        val now = System.currentTimeMillis()
        if (now - prefs.getLong("last_location_reminder_at", 0L) < REMINDER_INTERVAL) return
        prefs.edit().putLong("last_location_reminder_at", now).apply()
        val needsPermission = reason == "LOCATION_PERMISSION_DENIED" ||
            reason == "BACKGROUND_LOCATION_DENIED"
        val settings = if (needsPermission) {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        } else {
            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        }
        val settingsIntent = PendingIntent.getActivity(
            this, LOCATION_OFF_NOTIFICATION_ID,
            settings,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, UPDATES_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_carmelink)
            .setContentTitle("Location monitoring is off")
            .setContentText(if (needsPermission)
                "Allow precise location all the time to restore entry and exit alerts."
                else "Turn on Location to restore dormitory entry and exit alerts.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true).setContentIntent(settingsIntent)
            .addAction(0, if (needsPermission) "Open app settings" else "Turn on Location", settingsIntent).build()
        getSystemService(NotificationManager::class.java).notify(LOCATION_OFF_NOTIFICATION_ID, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Gate crossing verification",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shown briefly while CarmeLink confirms a gate crossing."
                },
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    UPDATES_CHANNEL_ID,
                    "CarmeLink updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Account, safety, payment, and dormitory updates."
                },
            )
        }
    }

    private fun showCrossingNotification(direction: String) {
        val isEntry = direction == "IN"
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route_type", "gate")
            putExtra("direction", direction)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            if (isEntry) ENTRY_NOTIFICATION_ID else EXIT_NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, UPDATES_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_carmelink)
            .setContentTitle(if (isEntry) "Entry detected" else "Exit detected")
            .setContentText(
                if (isEntry) "CarmeLink is syncing your entry."
                else "CarmeLink is syncing your departure.",
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        getSystemService(NotificationManager::class.java).notify(
            if (isEntry) ENTRY_NOTIFICATION_ID else EXIT_NOTIFICATION_ID,
            notification,
        )
    }
}
