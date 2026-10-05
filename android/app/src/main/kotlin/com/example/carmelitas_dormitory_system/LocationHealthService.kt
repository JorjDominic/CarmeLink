package com.example.carmelitas_dormitory_system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/** Settings observer only: never requests location or evaluates crossings. */
class LocationHealthService : Service() {
    companion object {
        @Volatile var running = false
            private set
    }
    private val handler = Handler(Looper.getMainLooper())
    private val check = object : Runnable {
        override fun run() {
            if (!getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
                    .getBoolean("registered", false)) {
                stopSelf()
                return
            }
            LocationMonitoringHealth.check(applicationContext)
            handler.postDelayed(this, 30_000L)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE)
                .getBoolean("registered", false)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (running) return START_STICKY
        LocationMonitoringHealth.observe(applicationContext)
        // Promote after Android has delivered the start/restart command, rather
        // than during construction of a service being recreated in background.
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                "carmelink_health_observer", "Location availability monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ))
        }
        val open = PendingIntent.getActivity(this, 9110, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        try {
            startForeground(9110, NotificationCompat.Builder(this, "carmelink_health_observer")
                .setSmallIcon(R.drawable.ic_stat_carmelink)
                .setContentTitle("CarmeLink safety monitoring")
                .setContentText("Checking that location monitoring remains available")
                .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true).build())
        } catch (error: RuntimeException) {
            LocationMonitoringHealth.observerFailed(this, error)
            LocationMonitoringHealth.check(applicationContext)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        running = true
        getSharedPreferences(TripwireGeofenceManager.PREFS, MODE_PRIVATE).edit()
            .remove("monitoring_observer_error")
            .putLong("monitoring_observer_started_at", System.currentTimeMillis()).apply()
        handler.post(check)
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
