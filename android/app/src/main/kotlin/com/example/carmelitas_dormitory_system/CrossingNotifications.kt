package com.example.carmelitas_dormitory_system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

object CrossingNotifications {
    fun show(context: Context, direction: String) {
        if (MainActivity.isInForeground) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel("carmelink_updates", "CarmeLink updates",
                NotificationManager.IMPORTANCE_HIGH))
        }
        val entry = direction == "IN"
        val id = if (entry) 1001 else 1002
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route_type", "gate")
            putExtra("direction", direction)
        }
        try {
            manager.notify(id, NotificationCompat.Builder(context, "carmelink_updates")
                .setSmallIcon(R.drawable.ic_stat_carmelink)
                .setContentTitle(if (entry) "Entry detected" else "Exit detected")
                .setContentText(if (entry) "CarmeLink is syncing your entry." else "CarmeLink is syncing your departure.")
                .setPriority(NotificationCompat.PRIORITY_HIGH).setAutoCancel(true)
                .setContentIntent(PendingIntent.getActivity(context, id, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build())
        } catch (error: RuntimeException) {
            // Local notification failure must not prevent uploading a crossing.
            Log.w("CarmeLinkTripwire", "Crossing reminder could not be posted", error)
        }
    }
}
