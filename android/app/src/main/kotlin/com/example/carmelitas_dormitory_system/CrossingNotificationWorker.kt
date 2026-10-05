package com.example.carmelitas_dormitory_system

import android.content.Context
import android.os.Build
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject

/** Delivery outbox stays separate from already recorded gate transitions. */
class CrossingNotificationWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        fun enqueue(context: Context, eventId: String, tenantId: String) {
            synchronized(TripwireGeofenceManager.EVENT_LOCK) {
                val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
                if (prefs.getString("tenant_id", null) != tenantId) return
                val queue = JSONArray(prefs.getString("pending_notifications", "[]"))
                if ((0 until queue.length()).none { queue.getJSONObject(it).getString("event_id") == eventId }) {
                    queue.put(JSONObject().put("event_id", eventId).put("tenant_id", tenantId))
                    check(prefs.edit().putString("pending_notifications", queue.toString()).commit())
                }
            }
            schedule(context)
        }

        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniqueWork("carmelink-crossing-notifications",
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                OneTimeWorkRequestBuilder<CrossingNotificationWorker>()
                    .apply { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                        setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST) }
                    .setConstraints(TripwireSyncWorker.constraints).build())
        }
    }

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        val snapshot = synchronized(TripwireGeofenceManager.EVENT_LOCK) {
            JSONArray(prefs.getString("pending_notifications", "[]"))
        }
        for (index in 0 until snapshot.length()) {
            val event = snapshot.getJSONObject(index)
            if (event.getString("tenant_id") != prefs.getString("tenant_id", null)) return Result.success()
            val response = try {
                TripwireApi(applicationContext).post("/functions/v1/notify-geofence",
                    JSONObject().put("event_id", event.getString("event_id")))
            } catch (error: Exception) {
                prefs.edit().putString("last_notification_error", "Notification network failure: ${error.javaClass.simpleName}").apply()
                return Result.retry()
            }
            if (response.first !in 200..299) {
                prefs.edit().putString("last_notification_error", "Notification delivery failed (${response.first})").apply()
                return Result.retry()
            }
            synchronized(TripwireGeofenceManager.EVENT_LOCK) {
                val current = JSONArray(prefs.getString("pending_notifications", "[]"))
                val remaining = JSONArray()
                for (item in 0 until current.length()) {
                    val candidate = current.getJSONObject(item)
                    if (candidate.getString("event_id") != event.getString("event_id")) remaining.put(candidate)
                }
                prefs.edit().putString("pending_notifications", remaining.toString())
                    .remove("last_notification_error").commit()
            }
        }
        return Result.success()
    }
}
