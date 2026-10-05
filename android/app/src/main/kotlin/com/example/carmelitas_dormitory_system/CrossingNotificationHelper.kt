package com.example.carmelitas_dormitory_system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Utility object for posting a local crossing notification from any context
 * (Worker, BroadcastReceiver, Service) without duplicating the notification
 * builder logic.
 */
object CrossingNotificationHelper {
    private const val UPDATES_CHANNEL_ID = "carmelink_updates"
    private const val ENTRY_NOTIFICATION_ID = 1001
    private const val EXIT_NOTIFICATION_ID = 1002

    fun show(context: Context, direction: String) {
        val isEntry = direction == "IN"
        ensureChannel(context)
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route_type", "gate")
            putExtra("direction", direction)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            if (isEntry) ENTRY_NOTIFICATION_ID else EXIT_NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, UPDATES_CHANNEL_ID)
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
        context.getSystemService(NotificationManager::class.java)
            .notify(if (isEntry) ENTRY_NOTIFICATION_ID else EXIT_NOTIFICATION_ID, notification)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(
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
