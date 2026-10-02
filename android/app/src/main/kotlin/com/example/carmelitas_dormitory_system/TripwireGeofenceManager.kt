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
        const val GATE_REGION_ID = "carmelita_official_gate"
        private const val QUEUE = "pending_events"
        const val QUEUED_DIRECTION = "queued_direction"

        fun appendEvent(context: Context, direction: String, observedAt: Long = System.currentTimeMillis()): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val tenantId = prefs.getString("tenant_id", null) ?: return false
            val previous = prefs.getString(QUEUED_DIRECTION, null)
                ?: prefs.getString("confirmed_direction", null)
            if (previous == direction) return false

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
                // A detected crossing is only pending until Supabase accepts it.
                // Keep it separate from the last server-confirmed direction.
                .putString(QUEUED_DIRECTION, direction)
                .apply()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "carmelink-tripwire-sync",
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                OneTimeWorkRequestBuilder<TripwireSyncWorker>()
                    .setConstraints(TripwireSyncWorker.constraints)
                    .build(),
            )
            return true
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

    private fun monitoringIntent(action: String = TripwireLocationBurstService.ACTION_START) =
        Intent(context, TripwireLocationBurstService::class.java).setAction(action)

    private fun startPersistentMonitoring() {
        if (!MainActivity.isInForeground) return
        try {
            ContextCompat.startForegroundService(context, monitoringIntent())
        } catch (_: RuntimeException) {
            // A geofence callback or the next visible app start retries this
            // if Android temporarily rejects a background service start.
        }
    }

    fun register(
        latitude: Double,
        longitude: Double,
        radiusMeters: Float,
        tenantId: String,
        initialDirection: String?,
        polygon: List<Map<String, Any>>,
        edgeBufferMeters: Float,
        gateEnabled: Boolean,
        gateStartLatitude: Double?,
        gateStartLongitude: Double?,
        gateEndLatitude: Double?,
        gateEndLongitude: Double?,
        gateToleranceMeters: Float,
        configVersion: Int,
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
            .putString("polygon", JSONArray(polygon).toString())
            .putFloat("edge_buffer_meters", edgeBufferMeters)
            .putBoolean("gate_enabled", gateEnabled)
            .putFloat("gate_tolerance_meters", gateToleranceMeters)
            .putInt("config_version", configVersion)
        if (gateStartLatitude != null && gateStartLongitude != null &&
            gateEndLatitude != null && gateEndLongitude != null) {
            editor.putLong("gate_start_latitude_bits", gateStartLatitude.toBits())
                .putLong("gate_start_longitude_bits", gateStartLongitude.toBits())
                .putLong("gate_end_latitude_bits", gateEndLatitude.toBits())
                .putLong("gate_end_longitude_bits", gateEndLongitude.toBits())
        }
        if (previousTenant != tenantId) {
            editor.remove(QUEUE)
            editor.remove("confirmed_direction")
            editor.remove(QUEUED_DIRECTION)
        }
        if (initialDirection == "IN" || initialDirection == "OUT") {
            editor.putString("confirmed_direction", initialDirection)
        }
        editor.remove("candidate_direction").remove("candidate_fix_count")
            .remove("candidate_started_at")
        editor.apply()

        // Seed the movement segment without creating an event. The next OS
        // callback can then prove which part of the boundary was crossed.
        try {
            LocationServices.getFusedLocationProviderClient(context).lastLocation
                .addOnSuccessListener { location ->
                    if (location != null) {
                        prefs.edit()
                            .putLong("last_latitude_bits", location.latitude.toBits())
                            .putLong("last_longitude_bits", location.longitude.toBits())
                            .putLong("last_location_at", location.time)
                            .apply()
                    }
                }
        } catch (_: SecurityException) { }

        // The low-power hardware geofence (Wi-Fi/cell-based) on Android needs
        // at least 100 m to fire reliably.  The on-device polygon in the
        // Flutter layer makes the final IN/OUT decision — this larger circle
        // only wakes the BroadcastReceiver so the polygon can be evaluated.
        val wakeUpRadius = radiusMeters.coerceAtLeast(100f)
        val geofences = mutableListOf(Geofence.Builder()
            .setRequestId(REGION_ID)
            .setCircularRegion(latitude, longitude, wakeUpRadius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            // 30 s is the minimum Android enforces; keeps the responsiveness
            // window small so the BroadcastReceiver fires promptly.
            .setNotificationResponsiveness(30_000)
            .build())
        if (gateEnabled && gateStartLatitude != null && gateStartLongitude != null &&
            gateEndLatitude != null && gateEndLongitude != null) {
            geofences.add(Geofence.Builder()
                .setRequestId(GATE_REGION_ID)
                .setCircularRegion(
                    (gateStartLatitude + gateEndLatitude) / 2.0,
                    (gateStartLongitude + gateEndLongitude) / 2.0,
                    maxOf(25f, gateToleranceMeters * 2f),
                )
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
                .setNotificationResponsiveness(10_000)
                .build())
        }
        val request = GeofencingRequest.Builder()
            // INITIAL_TRIGGER_ENTER tells Play Services to immediately report
            // whether the device is already inside when monitoring starts.
            // Without this the first EXIT event after a cold-start is often
            // skipped, causing the native queue to miss the student leaving.
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER or GeofencingRequest.INITIAL_TRIGGER_EXIT)
            .addGeofences(geofences)
            .build()

        client.removeGeofences(pendingIntent).addOnCompleteListener {
            try {
                client.addGeofences(request, pendingIntent)
                    .addOnSuccessListener {
                        // Keep exact polygon monitoring alive after the task is
                        // removed from Recents. Android still stops it after a
                        // user-initiated Force Stop until the app is reopened.
                        startPersistentMonitoring()
                        result.success(true)
                    }
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
        val polygonArray = try { JSONArray(prefs.getString("polygon", "[]")) } catch (_: Exception) { JSONArray() }
        val polygon = (0 until polygonArray.length()).map { index ->
            val item = polygonArray.getJSONObject(index)
            mapOf<String, Any>("lat" to item.getDouble("lat"), "lng" to item.getDouble("lng"))
        }
        register(latitude, longitude, radius, tenantId, prefs.getString("confirmed_direction", null),
            polygon, prefs.getFloat("edge_buffer_meters", 3f), prefs.getBoolean("gate_enabled", false),
            if (prefs.contains("gate_start_latitude_bits")) Double.fromBits(prefs.getLong("gate_start_latitude_bits", 0)) else null,
            if (prefs.contains("gate_start_longitude_bits")) Double.fromBits(prefs.getLong("gate_start_longitude_bits", 0)) else null,
            if (prefs.contains("gate_end_latitude_bits")) Double.fromBits(prefs.getLong("gate_end_latitude_bits", 0)) else null,
            if (prefs.contains("gate_end_longitude_bits")) Double.fromBits(prefs.getLong("gate_end_longitude_bits", 0)) else null,
            prefs.getFloat("gate_tolerance_meters", 15f), prefs.getInt("config_version", 1),
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
            context.stopService(monitoringIntent(TripwireLocationBurstService.ACTION_STOP))
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
        var acknowledgedDirection: String? = null
        for (index in 0 until queue.length()) {
            val item = queue.getJSONObject(index)
            if (item.optString("event_id") != eventId) {
                remaining.put(item)
            } else {
                acknowledgedDirection = item.optString("direction").takeIf { it == "IN" || it == "OUT" }
            }
        }
        val editor = prefs.edit().putString(QUEUE, remaining.toString())
        acknowledgedDirection?.let { editor.putString("confirmed_direction", it) }
        if (remaining.length() == 0) {
            editor.remove(QUEUED_DIRECTION)
        } else {
            editor.putString(QUEUED_DIRECTION, remaining.getJSONObject(remaining.length() - 1).getString("direction"))
        }
        editor.apply()
    }

    fun status(): Map<String, Any?> = mapOf(
        "registered" to prefs.getBoolean("registered", false),
        "gateEnabled" to prefs.getBoolean("gate_enabled", false),
        "configVersion" to prefs.getInt("config_version", 1),
        "direction" to prefs.getString("confirmed_direction", null),
        "pendingDirection" to prefs.getString(QUEUED_DIRECTION, null),
        "candidateDirection" to prefs.getString("candidate_direction", null),
        "candidateFixCount" to prefs.getInt("candidate_fix_count", 0),
        "pendingCount" to try { JSONArray(prefs.getString(QUEUE, "[]")).length() } catch (_: Exception) { 0 },
        "lastSyncError" to prefs.getString("last_sync_error", null),
        "lastSyncedAt" to prefs.getLong("last_synced_at", 0L).takeIf { it > 0L },
    )
}
