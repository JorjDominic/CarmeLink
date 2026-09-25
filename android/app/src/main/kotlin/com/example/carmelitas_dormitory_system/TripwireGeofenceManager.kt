package com.example.carmelitas_dormitory_system

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class TripwireGeofenceManager(private val context: Context) {
    companion object {
        const val PREFS = "carmelink_tripwire"
        const val REGION_ID = "carmelita_dormitory"
        private const val QUEUE = "pending_events"

        fun appendEvent(context: Context, direction: String, observedAt: Long = System.currentTimeMillis()) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val tenantId = prefs.getString("tenant_id", null) ?: return
            val previous = prefs.getString("confirmed_direction", null)
            if (previous == direction) return

            val queue = try {
                JSONArray(prefs.getString(QUEUE, "[]"))
            } catch (_: Exception) {
                JSONArray()
            }
            val event = JSONObject()
                .put("event_id", UUID.randomUUID().toString())
                .put("tenant_id", tenantId)
                .put("direction", direction)
                .put("observed_at", observedAt)
                .put("platform", "android")
            queue.put(event)

            val bounded = JSONArray()
            val start = maxOf(0, queue.length() - 24)
            for (index in start until queue.length()) bounded.put(queue.get(index))
            prefs.edit()
                .putString(QUEUE, bounded.toString())
                .putString("confirmed_direction", direction)
                .apply()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "carmelink-tripwire-sync",
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                OneTimeWorkRequestBuilder<TripwireSyncWorker>()
                    .setConstraints(TripwireSyncWorker.constraints)
                    .build(),
            )
        }
    }

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val client = LocationServices.getGeofencingClient(context)
    private val pendingIntent: PendingIntent
        get() = PendingIntent.getBroadcast(
            context,
            9107,
            Intent(context, GeofenceBroadcastReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    fun register(
        latitude: Double,
        longitude: Double,
        radiusMeters: Float,
        tenantId: String,
        initialDirection: String?,
        accessToken: String,
        refreshToken: String,
        supabaseUrl: String,
        publishableKey: String,
        result: MethodChannel.Result,
    ) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("permission_denied", "Precise location permission is required.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("background_permission_denied", "Background location permission is required.", null)
            return
        }

        val previousTenant = prefs.getString("tenant_id", null)
        val editor = prefs.edit()
            .putString("tenant_id", tenantId)
            .putLong("latitude_bits", latitude.toBits())
            .putLong("longitude_bits", longitude.toBits())
            .putFloat("radius_meters", radiusMeters)
            .putBoolean("registered", true)
            .putString("access_token", accessToken)
            .putString("refresh_token", refreshToken)
            .putString("supabase_url", supabaseUrl)
            .putString("publishable_key", publishableKey)
        if (previousTenant != tenantId) {
            editor.remove(QUEUE)
            editor.remove("confirmed_direction")
        }
        if (initialDirection == "IN" || initialDirection == "OUT") {
            editor.putString("confirmed_direction", initialDirection)
        }
        editor.apply()

        // The low-power hardware geofence (Wi-Fi/cell-based) on Android needs
        // at least 100 m to fire reliably.  The on-device polygon in the
        // Flutter layer makes the final IN/OUT decision — this larger circle
        // only wakes the BroadcastReceiver so the polygon can be evaluated.
        val wakeUpRadius = radiusMeters.coerceAtLeast(100f)
        val geofence = Geofence.Builder()
            .setRequestId(REGION_ID)
            .setCircularRegion(latitude, longitude, wakeUpRadius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            // 30 s is the minimum Android enforces; keeps the responsiveness
            // window small so the BroadcastReceiver fires promptly.
            .setNotificationResponsiveness(30_000)
            .build()
        val request = GeofencingRequest.Builder()
            // INITIAL_TRIGGER_ENTER tells Play Services to immediately report
            // whether the device is already inside when monitoring starts.
            // Without this the first EXIT event after a cold-start is often
            // skipped, causing the native queue to miss the student leaving.
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER or GeofencingRequest.INITIAL_TRIGGER_EXIT)
            .addGeofence(geofence)
            .build()

        client.removeGeofences(pendingIntent).addOnCompleteListener {
            try {
                client.addGeofences(request, pendingIntent)
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { error ->
                        prefs.edit().putBoolean("registered", false).apply()
                        result.error("registration_failed", error.message, null)
                    }
            } catch (error: SecurityException) {
                prefs.edit().putBoolean("registered", false).apply()
                result.error("permission_denied", error.message, null)
            }
        }
    }

    fun restore() {
        if (!prefs.getBoolean("registered", false)) return
        val tenantId = prefs.getString("tenant_id", null) ?: return
        val latitude = Double.fromBits(prefs.getLong("latitude_bits", 0L))
        val longitude = Double.fromBits(prefs.getLong("longitude_bits", 0L))
        val radius = prefs.getFloat("radius_meters", 50f)
        register(latitude, longitude, radius, tenantId, prefs.getString("confirmed_direction", null),
            prefs.getString("access_token", null) ?: return,
            prefs.getString("refresh_token", null) ?: return,
            prefs.getString("supabase_url", null) ?: return,
            prefs.getString("publishable_key", null) ?: return,
            object : MethodChannel.Result {
                override fun success(result: Any?) = Unit
                override fun error(code: String, message: String?, details: Any?) = Unit
                override fun notImplemented() = Unit
            })
    }

    fun unregister(result: MethodChannel.Result) {
        client.removeGeofences(pendingIntent).addOnCompleteListener {
            prefs.edit().clear().apply()
            result.success(true)
        }
    }

    fun consumePending(): List<Map<String, Any>> {
        val now = System.currentTimeMillis()
        val minimum = now - 24L * 60L * 60L * 1000L
        val queue = try { JSONArray(prefs.getString(QUEUE, "[]")) } catch (_: Exception) { JSONArray() }
        val events = mutableListOf<Map<String, Any>>()
        for (index in 0 until queue.length()) {
            val item = queue.getJSONObject(index)
            val observedAt = item.optLong("observed_at")
            if (observedAt >= minimum) {
                events.add(mapOf(
                    "event_id" to item.getString("event_id"),
                    "tenant_id" to item.getString("tenant_id"),
                    "direction" to item.getString("direction"),
                    "observed_at" to observedAt,
                    "platform" to "android",
                ))
            }
        }
        return events
    }

    fun acknowledge(eventId: String) {
        val queue = try { JSONArray(prefs.getString(QUEUE, "[]")) } catch (_: Exception) { JSONArray() }
        val remaining = JSONArray()
        for (index in 0 until queue.length()) {
            val item = queue.getJSONObject(index)
            if (item.optString("event_id") != eventId) remaining.put(item)
        }
        prefs.edit().putString(QUEUE, remaining.toString()).apply()
    }

    fun status(): Map<String, Any?> = mapOf(
        "registered" to prefs.getBoolean("registered", false),
        "direction" to prefs.getString("confirmed_direction", null),
        "pendingCount" to try { JSONArray(prefs.getString(QUEUE, "[]")).length() } catch (_: Exception) { 0 },
    )
}
