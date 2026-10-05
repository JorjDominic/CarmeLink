package com.example.carmelitas_dormitory_system

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit

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
 *   1. Requests two fresh, time-separated high-accuracy fixes.
 *   2. Runs TripwireCrossingVerifier.accept() against the stored polygon.
 *   3. If a crossing is confirmed, calls TripwireGeofenceManager.appendEvent()
 *      which automatically enqueues TripwireSyncWorker to upload the event.
 *   4. Stores the OS transition as a wake hint for recovery diagnostics.
 */
class GeofenceTransitionWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        const val KEY_TRANSITION = "geofence_transition_type"
        const val KEY_LATITUDE = "trigger_latitude"
        const val KEY_LONGITUDE = "trigger_longitude"
        const val KEY_ACCURACY = "trigger_accuracy"
        const val KEY_SPEED = "trigger_speed"
        const val KEY_HAS_SPEED = "trigger_has_speed"
        const val KEY_LOCATION_TIME = "trigger_location_time"
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

        fun recordIfAccepted(location: Location): Boolean {
            val direction = TripwireCrossingVerifier.accept(applicationContext, location)
                ?: return false
            val queued = TripwireGeofenceManager.appendEvent(
                applicationContext,
                direction,
                System.currentTimeMillis(),
            )
            if (queued) CrossingNotificationHelper.show(applicationContext, direction)
            return true
        }

        // Use Play Services' triggering fix as the first observation. This is
        // available immediately even when a new background GPS request is
        // throttled, and one fresh fix still has to confirm the crossing.
        return try {
            val flpClient = LocationServices.getFusedLocationProviderClient(applicationContext)
            val hasTriggerLocation = inputData.getLong(KEY_LOCATION_TIME, 0L) > 0L
            if (hasTriggerLocation) {
                val triggerLocation = Location("geofence").apply {
                    latitude = inputData.getDouble(KEY_LATITUDE, 0.0)
                    longitude = inputData.getDouble(KEY_LONGITUDE, 0.0)
                    accuracy = inputData.getFloat(KEY_ACCURACY, Float.MAX_VALUE)
                    time = inputData.getLong(KEY_LOCATION_TIME, System.currentTimeMillis())
                    if (inputData.getBoolean(KEY_HAS_SPEED, false)) {
                        speed = inputData.getFloat(KEY_SPEED, 0f)
                    }
                }
                if (recordIfAccepted(triggerLocation)) return Result.success()
                Thread.sleep(8_000L)
            }

            val freshFixCount = if (hasTriggerLocation) 1 else 2
            repeat(freshFixCount) { index ->
                val request = CurrentLocationRequest.Builder()
                    .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                    .setMaxUpdateAgeMillis(0L)
                    .setDurationMillis(12_000L)
                    .build()
                val location = Tasks.await(
                    flpClient.getCurrentLocation(request, null),
                    15,
                    TimeUnit.SECONDS,
                )
                if (location != null && recordIfAccepted(location)) return Result.success()
                if (!hasTriggerLocation && index == 0) Thread.sleep(8_000L)
            }
            Result.success()
        } catch (_: SecurityException) {
            Result.failure()
        } catch (_: Exception) {
            Result.retry()
        }
    }
}
