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
 * Short, bounded high-accuracy session started by an OS geofence callback.
 * It bridges the gap between a circular wake-up region and the exact polygon
 * crossing. It stops after a confirmed transition or after two minutes.
 */
class TripwireLocationBurstService : Service() {
    companion object {
        private const val CHANNEL_ID = "carmelink_tripwire_monitoring"
        private const val NOTIFICATION_ID = 9108
        private const val MAX_DURATION_MILLIS = 120_000L
    }

    private val locationClient by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private var running = false
    private val timeout = Runnable { stopBurst() }
    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            for (location in result.locations) {
                val direction = TripwireCrossingVerifier.accept(this@TripwireLocationBurstService, location)
                if (direction != null) {
                    TripwireGeofenceManager.appendEvent(
                        this@TripwireLocationBurstService,
                        direction,
                        location.time,
                    )
                    stopBurst()
                    return
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_carmelink)
                .setContentTitle("CarmeLink gate verification")
                .setContentText("Confirming a dormitory boundary crossing")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build(),
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!running) startBurst()
        return START_NOT_STICKY
    }

    private fun startBurst() {
        if (!getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
                .getBoolean("gate_enabled", false)
        ) {
            stopSelf()
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            stopSelf()
            return
        }

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5_000L)
            .setMinUpdateIntervalMillis(3_000L)
            .setMaxUpdateAgeMillis(5_000L)
            .setDurationMillis(MAX_DURATION_MILLIS)
            .build()
        try {
            running = true
            locationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
            android.os.Handler(Looper.getMainLooper()).postDelayed(timeout, MAX_DURATION_MILLIS)
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
        }
    }
}
