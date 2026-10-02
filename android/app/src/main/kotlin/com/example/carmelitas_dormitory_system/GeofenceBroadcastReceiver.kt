package com.example.carmelitas_dormitory_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
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

        // Android can safely enqueue this worker from a background receiver,
        // including when a new foreground service may not be promoted.
        val inputData = Data.Builder()
            .putInt(GeofenceTransitionWorker.KEY_TRANSITION, transition)
            .apply {
                event.triggeringLocation?.let { location ->
                    putDouble(GeofenceTransitionWorker.KEY_LATITUDE, location.latitude)
                    putDouble(GeofenceTransitionWorker.KEY_LONGITUDE, location.longitude)
                    putFloat(GeofenceTransitionWorker.KEY_ACCURACY, location.accuracy)
                    putFloat(GeofenceTransitionWorker.KEY_SPEED, location.speed)
                    putBoolean(GeofenceTransitionWorker.KEY_HAS_SPEED, location.hasSpeed())
                    putLong(GeofenceTransitionWorker.KEY_LOCATION_TIME, location.time)
                }
            }
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            "carmelink-geofence-transition",
            // Multiple registered regions can report the same physical
            // crossing. Never cancel a verifier that is already waiting for
            // its confirmation fix; the verifier and appendEvent still
            // de-duplicate the final direction.
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            OneTimeWorkRequestBuilder<GeofenceTransitionWorker>()
                .setInputData(inputData)
                // Ordinary work is commonly deferred while an OEM considers
                // the closed app idle, then appears to run when it is opened.
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build(),
        )
    }
}
