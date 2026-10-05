package com.example.carmelitas_dormitory_system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/** Settings observer only: never requests location or evaluates crossings. */
class LocationHealthService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            LocationMonitoringHealth.check(applicationContext)
        }
    }
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

    override fun onCreate() {
        super.onCreate()
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
        } catch (_: RuntimeException) {
            stopSelf()
            return
        }
        val filter = IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) addAction(LocationManager.MODE_CHANGED_ACTION)
        }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        receiverRegistered = true
        handler.post(check)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (receiverRegistered) unregisterReceiver(receiver)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
