package com.example.carmelitas_dormitory_system

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.work.*
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit

/** Durable, bounded fallback when an OS callback cannot start the GPS service. */
class GeofenceVerificationWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        fun enqueue(context: Context) {
            val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean("registered", false)) return
            WorkManager.getInstance(context).enqueueUniqueWork("carmelink-geofence-verification",
                ExistingWorkPolicy.KEEP,
                OneTimeWorkRequestBuilder<GeofenceVerificationWorker>()
                    .setInputData(Data.Builder().putString("tenant_id", prefs.getString("tenant_id", null)).build())
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
                    .apply { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                        setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST) }
                    .build())
        }
    }

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("registered", false) || inputData.getString("tenant_id") != prefs.getString("tenant_id", null)) return Result.success()
        if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
            PackageManager.PERMISSION_GRANTED)) return Result.success()
        return try {
            val client = LocationServices.getFusedLocationProviderClient(applicationContext)
            repeat(3) { index ->
                if (isStopped) return Result.retry()
                val request = CurrentLocationRequest.Builder().setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                    .setMaxUpdateAgeMillis(0L).setDurationMillis(12_000L).build()
                val location = Tasks.await(client.getCurrentLocation(request, null), 15, TimeUnit.SECONDS)
                if (location != null) {
                    val direction = TripwireGeofenceManager.verifyAndAppend(applicationContext, location)
                    if (direction != null) {
                        CrossingNotifications.show(applicationContext, direction)
                        prefs.edit().remove("last_verification_error").apply()
                        return Result.success()
                    }
                }
                if (index < 2) Thread.sleep(3_000L)
            }
            prefs.edit().putString("last_verification_error", "Fallback did not confirm a fresh two-fix crossing").apply()
            if (runAttemptCount < 3) Result.retry() else Result.success()
        } catch (error: Exception) {
            prefs.edit().putString("last_verification_error", "Verification failed: ${error.javaClass.simpleName}").apply()
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }
}
