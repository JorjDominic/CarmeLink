package com.example.carmelitas_dormitory_system

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.location.LocationServices
import com.google.android.gms.tasks.Tasks

/**
 * WorkManager worker that handles a geofence transition while the app is
 * killed or in the background.
 *
 * Android 12+ forbids starting a foreground service from a background
 * BroadcastReceiver (ForegroundServiceStartNotAllowedException).  WorkManager
 * jobs are always allowed from a BroadcastReceiver context, so the
 * GeofenceBroadcastReceiver enqueues this worker instead of (or before)
 * attempting to start the foreground service.
 *
 * This worker:
 *   1. Reads the last known GPS fix from the Fused Location Provider.
 *   2. Runs TripwireCrossingVerifier.accept() against the stored polygon.
 *   3. If a crossing is confirmed, calls TripwireGeofenceManager.appendEvent()
 *      which automatically enqueues TripwireSyncWorker to upload the event.
 *   4. If no confirmed crossing yet (first fix), stores a "wake hint" so the
 *      next fix from the foreground service can complete the confirmation.
 */
class GeofenceTransitionWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        const val KEY_TRANSITION = "geofence_transition_type"
        // GEOFENCE_TRANSITION_ENTER = 1, GEOFENCE_TRANSITION_EXIT = 2
        const val TRANSITION_ENTER = 1
        const val TRANSITION_EXIT = 2
    }

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(
            TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE,
        )
        if (!prefs.getBoolean("registered", false)) return Result.success()

        // Hint stored for the foreground service to pick up on the next
        // accurate fix. The OS transition type (ENTER/EXIT) tells us which
        // side the device likely crossed to, which primes the candidate.
        val transition = inputData.getInt(KEY_TRANSITION, 0)
        if (transition == TRANSITION_ENTER || transition == TRANSITION_EXIT) {
            prefs.edit()
                .putInt("last_geofence_transition", transition)
                .putLong("last_geofence_transition_at", System.currentTimeMillis())
                .apply()
        }

        if (ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) != PackageManager.PERMISSION_GRANTED
        ) return Result.success()

        // Attempt to get the last known location and run the verifier once.
        // This single fix is often inaccurate enough to be rejected by the
        // verifier (accuracy gate is 35 m) but it primes the candidate state
        // so that the foreground service needs only ONE more fix to confirm.
        return try {
            val flpClient = LocationServices.getFusedLocationProviderClient(applicationContext)
            val location = Tasks.await(flpClient.lastLocation) // blocking; fine inside a Worker
            if (location != null) {
                val direction = TripwireCrossingVerifier.accept(applicationContext, location)
                if (direction != null) {
                    val queued = TripwireGeofenceManager.appendEvent(
                        applicationContext,
                        direction,
                        System.currentTimeMillis(),
                    )
                    if (queued) {
                        // Show a local notification so the tenant is aware even
                        // if the foreground service did not start.
                        CrossingNotificationHelper.show(applicationContext, direction)
                    }
                }
            }
            Result.success()
        } catch (_: Exception) {
            Result.success() // Non-critical; foreground service will catch up
        }
    }
}
