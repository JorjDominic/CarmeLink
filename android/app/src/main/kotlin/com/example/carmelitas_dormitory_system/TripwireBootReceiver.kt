package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TripwireBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            TripwireGeofenceManager(context.applicationContext).restore()
        }
    }
}
