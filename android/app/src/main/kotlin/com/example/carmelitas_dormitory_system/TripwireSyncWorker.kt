package com.example.carmelitas_dormitory_system

import android.content.Context
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Upload transitions idempotently; hand server notification IDs to a separate outbox. */
class TripwireSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        val constraints: Constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
    }

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        val snapshot = synchronized(TripwireGeofenceManager.EVENT_LOCK) {
            JSONArray(prefs.getString("pending_events", "[]"))
        }
        val manager = TripwireGeofenceManager(applicationContext)
        for (index in 0 until snapshot.length()) {
            val event = snapshot.getJSONObject(index)
            if (event.getString("tenant_id") != prefs.getString("tenant_id", null)) return Result.success()
            if (System.currentTimeMillis() - event.getLong("observed_at") > 24L * 60L * 60L * 1000L) {
                manager.acknowledge(event.getString("event_id"), confirm = false)
                continue
            }
            val response = try {
                TripwireApi(applicationContext).post("/rest/v1/rpc/record_tenant_geofence_transition",
                    JSONObject().put("p_direction", event.getString("direction"))
                        .put("p_observed_at", isoTimestamp(event.getLong("observed_at")))
                        .put("p_client_event_id", event.getString("event_id")))
            } catch (error: Exception) {
                prefs.edit().putString("last_sync_error", "Gate event network failure: ${error.javaClass.simpleName}").apply()
                return Result.retry()
            }
            if (response.first !in 200..299) {
                prefs.edit().putString("last_sync_error", "Gate event sync failed (${response.first}): ${response.second.take(500)}").apply()
                return if (response.first in listOf(401, 408, 429) || response.first >= 500) Result.retry() else Result.failure()
            }
            val serverEventId = response.second.trim().removeSurrounding("\"")
            if (serverEventId.isBlank() || serverEventId == "null") {
                prefs.edit().putString("last_sync_error", "Server did not return a gate event ID").apply()
                return Result.retry()
            }
            // Persist delivery before acknowledging the uploaded event. Replaying
            // after a crash uses the same client ID and cannot create another gate event.
            CrossingNotificationWorker.enqueue(applicationContext, serverEventId, event.getString("tenant_id"))
            manager.acknowledge(event.getString("event_id"))
            prefs.edit().putLong("last_synced_at", System.currentTimeMillis()).remove("last_sync_error").apply()
        }
        return Result.success()
    }

    private fun isoTimestamp(milliseconds: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(milliseconds))
}
