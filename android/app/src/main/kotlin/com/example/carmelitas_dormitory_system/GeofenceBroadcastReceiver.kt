package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import androidx.core.content.ContextCompat

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER &&
            event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_EXIT) return
        try {
            ContextCompat.startForegroundService(
                context,
                Intent(context, TripwireLocationBurstService::class.java),
            )
        } catch (_: RuntimeException) {
            // The OS can deny background foreground-service starts under
            // exceptional battery or policy restrictions. Monitoring health
            // will recover on the next eligible geofence callback/app resume.
        }
    }
}
