package com.example.carmelitas_dormitory_system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Ongoing location monitor started while the tenant app is visible.
 * Near the polygon it samples precisely; farther away it reduces power use.
 * OS callbacks can also start a bounded two-minute verification session.
 */
class TripwireLocationBurstService : Service() {
    companion object {
        @Volatile var monitoring = false
            private set
        private const val CHANNEL_ID = "carmelink_tripwire_monitoring"
        private const val UPDATES_CHANNEL_ID = "carmelink_updates"
        private const val NOTIFICATION_ID = 9108
        private const val MAX_DURATION_MILLIS = 120_000L
    }

    private val locationClient by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private var running = false
    private var continuous = false
    private var precise = true
    private val timeout = Runnable { stopBurst() }
    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            for (location in result.locations) {
                val direction = TripwireGeofenceManager.verifyAndAppend(this@TripwireLocationBurstService, location)
                if (direction != null) {
                    CrossingNotifications.show(this@TripwireLocationBurstService, direction)
                    if (!continuous) { stopBurst(); return }
                }
                if (continuous) updateSampling(TripwireCrossingVerifier.needsPreciseSampling(
                    this@TripwireLocationBurstService, location))
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean("registered", false)) { stopSelf(startId); return START_NOT_STICKY }
        // Sticky restart recovers ongoing monitoring; geofence callbacks can
        // also request bounded verification when no monitor has been started.
        continuous = continuous || intent == null || intent.getBooleanExtra("continuous", false)
        if (running) {
            monitoring = continuous
            if (continuous) android.os.Handler(Looper.getMainLooper()).removeCallbacks(timeout)
            return if (continuous) START_STICKY else START_NOT_STICKY
        }
        createNotificationChannel()
        try {
            startForeground(
                NOTIFICATION_ID,
                NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_stat_carmelink)
                    .setContentTitle(if (continuous) "CarmeLink boundary monitoring" else "CarmeLink gate verification")
                    .setContentText(if (continuous) "Entry and exit detection is active" else "Confirming a dormitory boundary crossing")
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setOngoing(true)
                    .setOnlyAlertOnce(true)
                    .build(),
            )
        } catch (error: RuntimeException) {
            prefs.edit().putString("last_verification_error", "${error.javaClass.simpleName}: ${error.message}").apply()
            GeofenceVerificationWorker.enqueue(applicationContext)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        startBurst()
        monitoring = continuous && running
        return if (continuous) START_STICKY else START_NOT_STICKY
    }

    private fun startBurst() {
        // Always start a high-accuracy burst whenever the coarse OS geofence
        // fires — TripwireCrossingVerifier needs a precise GPS fix to evaluate
        // the polygon, regardless of whether the virtual gate line is configured.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            stopSelf()
            return
        }

        updateSampling(true)
        if (!continuous) android.os.Handler(Looper.getMainLooper()).postDelayed(timeout, MAX_DURATION_MILLIS)
    }

    private fun updateSampling(highAccuracy: Boolean) {
        if (running && precise == highAccuracy) return
        val request = LocationRequest.Builder(
            if (highAccuracy) Priority.PRIORITY_HIGH_ACCURACY else Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            if (highAccuracy) 5_000L else 30_000L)
            .setMinUpdateIntervalMillis(if (highAccuracy) 3_000L else 15_000L)
            .setMinUpdateDistanceMeters(if (highAccuracy) 0f else 10f)
            .setMaxUpdateAgeMillis(5_000L).build()
        try {
            if (running) locationClient.removeLocationUpdates(callback)
            precise = highAccuracy
            running = true
            locationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
                .addOnFailureListener { error ->
                    getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE).edit()
                        .putString("last_verification_error", "Location updates failed: ${error.message}").apply()
                    GeofenceVerificationWorker.enqueue(applicationContext)
                    stopBurst()
                }
        } catch (_: SecurityException) {
            stopBurst()
        }
    }

    private fun stopBurst() {
        android.os.Handler(Looper.getMainLooper()).removeCallbacks(timeout)
        if (running) locationClient.removeLocationUpdates(callback)
        running = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        monitoring = false
        android.os.Handler(Looper.getMainLooper()).removeCallbacks(timeout)
        if (running) locationClient.removeLocationUpdates(callback)
        running = false
        super.onDestroy()
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

}
