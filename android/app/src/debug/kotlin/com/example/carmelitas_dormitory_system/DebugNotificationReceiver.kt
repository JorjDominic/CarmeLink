package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Debug-build-only hook used to validate notifications with the UI closed. */
class DebugNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val direction = intent.getStringExtra("direction")
            ?.uppercase()
            ?.takeIf { it == "IN" || it == "OUT" }
            ?: "IN"
        CrossingNotificationHelper.show(context, direction)
    }
}
