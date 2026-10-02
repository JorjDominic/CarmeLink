package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class TripwireBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            val appContext = context.applicationContext
            // Re-register the OS-level circular geofences with Google Play
            // Services so the GeofenceBroadcastReceiver fires again.
            TripwireGeofenceManager(appContext).restore()

            // A boot receiver IS allowed to start a foreground service under
            // Android's boot-completed exemption (documented in
            // ActivityManager.isBackgroundRestricted() exemption list).
            // Starting the persistent monitoring service here ensures the
            // exact-polygon verifier is running immediately after a reboot,
            // without waiting for the tenant to open the app.
            val prefs = appContext.getSharedPreferences(
                TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE,
            )
            if (prefs.getBoolean("registered", false)) {
                try {
                    ContextCompat.startForegroundService(
                        appContext,
                        Intent(appContext, TripwireLocationBurstService::class.java)
                            .setAction(TripwireLocationBurstService.ACTION_START),
                    )
                } catch (_: RuntimeException) {
                    // Fail-safe: geofences are re-registered above, so the
                    // BroadcastReceiver + WorkManager path still fires on the
                    // next crossing even if the foreground service can't start.
                }
            }
        }
    }
}
