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
        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (event.hasError()) {
            prefs.edit().putString("last_verification_error", "Geofence callback error: ${event.errorCode}").apply()
            return
        }
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER &&
            event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_EXIT) return
        prefs.edit().putLong("last_geofence_callback_at", System.currentTimeMillis()).apply()
        GeofenceVerificationWorker.enqueue(context)
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
