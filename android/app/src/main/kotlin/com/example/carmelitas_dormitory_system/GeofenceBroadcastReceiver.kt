package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        val transition = event.geofenceTransition
        if (transition != Geofence.GEOFENCE_TRANSITION_ENTER &&
            transition != Geofence.GEOFENCE_TRANSITION_EXIT
        ) return

        // PRIMARY PATH — always works regardless of whether the app is killed.
        // WorkManager is explicitly allowed to be enqueued from a background
        // BroadcastReceiver even on Android 12+ (unlike startForegroundService,
        // which throws ForegroundServiceStartNotAllowedException when the app is
        // in the background or killed).
        val inputData = Data.Builder()
            .putInt(GeofenceTransitionWorker.KEY_TRANSITION, transition)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            "carmelink-geofence-transition",
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            OneTimeWorkRequestBuilder<GeofenceTransitionWorker>()
                .setInputData(inputData)
                .build(),
        )

        // SECONDARY PATH — attempts to start the persistent foreground service
        // for higher-accuracy continuous fixes. Allowed unconditionally on
        // Android 8–11 and when the app has an active foreground window on 12+.
        // Silently ignored if the OS blocks it; the WorkManager job above
        // already handles the transition safely.
        try {
            ContextCompat.startForegroundService(
                context,
                Intent(context, TripwireLocationBurstService::class.java)
                    .setAction(TripwireLocationBurstService.ACTION_START),
            )
        } catch (_: RuntimeException) {
            // ForegroundServiceStartNotAllowedException on Android 12+ when the
            // app is fully stopped. The WorkManager job is the reliable path.
        }
    }
}
