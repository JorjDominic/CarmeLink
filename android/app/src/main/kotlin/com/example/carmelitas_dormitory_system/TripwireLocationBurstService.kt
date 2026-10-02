package com.example.carmelitas_dormitory_system

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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
    }

    private val locationClient by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private var running = false
    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            for (location in result.locations) {
                val direction = TripwireCrossingVerifier.accept(this@TripwireLocationBurstService, location)
                if (direction != null) {
                    val queued = TripwireGeofenceManager.appendEvent(
                        this@TripwireLocationBurstService,
                        direction,
                        // Use the detection time. Some Android providers and
                        // emulators expose a stale fix timestamp even though
                        // this high-accuracy callback has just been delivered.
                        System.currentTimeMillis(),
                    )
                    if (queued && !MainActivity.isInForeground) {
                        showCrossingNotification(direction)
                    }
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
                .setContentTitle("CarmeLink location monitoring")
                .setContentText("Dormitory boundary alerts are active")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build(),
        )
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

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 15_000L)
            .setMinUpdateIntervalMillis(8_000L)
            .setMinUpdateDistanceMeters(5f)
            .setMaxUpdateAgeMillis(10_000L)
            .build()
        try {
            running = true
            locationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (_: SecurityException) {
            stopMonitoring()
        }
    }

    private fun stopMonitoring() {
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
