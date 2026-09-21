package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        val direction = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "IN"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "OUT"
            else -> return
        }
        TripwireGeofenceManager.appendEvent(context, direction)
    }
}
