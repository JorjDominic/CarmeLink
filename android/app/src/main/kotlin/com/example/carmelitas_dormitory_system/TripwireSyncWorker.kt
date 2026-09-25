package com.example.carmelitas_dormitory_system

import android.content.Context
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Uploads minimized tripwire events without launching the application UI. */
class TripwireSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        /** WorkManager Constraints that enforce a network connection before running. */
        val constraints: Constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
    }

    private val prefs = context.getSharedPreferences(
        TripwireGeofenceManager.PREFS,
        Context.MODE_PRIVATE,
    )

    override fun doWork(): Result {
        val baseUrl = prefs.getString("supabase_url", null) ?: return Result.failure()
        val apiKey = prefs.getString("publishable_key", null) ?: return Result.failure()
        var accessToken = prefs.getString("access_token", null) ?: return Result.retry()
        val queue = try {
            JSONArray(prefs.getString("pending_events", "[]"))
        } catch (_: Exception) {
            return Result.failure()
        }
        if (queue.length() == 0) return Result.success()

        val remaining = JSONArray()
        for (index in 0 until queue.length()) {
            val event = queue.getJSONObject(index)
            val age = System.currentTimeMillis() - event.optLong("observed_at")
            if (age > 24L * 60L * 60L * 1000L) continue

            val response: Int
            try {
                var r = send(baseUrl, apiKey, accessToken, event)
                if (r == HttpURLConnection.HTTP_UNAUTHORIZED) {
                    accessToken = refreshSession(baseUrl, apiKey) ?: run {
                        for (pending in index until queue.length()) remaining.put(queue.get(pending))
                        persist(remaining)
                        return Result.retry()
                    }
                    r = send(baseUrl, apiKey, accessToken, event)
                }
                response = r
            } catch (e: IOException) {
                // Network became unavailable mid-flight (e.g. Wi-Fi→mobile
                // handoff at the dorm gate).  Keep all remaining events and
                // let WorkManager retry when connectivity is restored.
                for (pending in index until queue.length()) remaining.put(queue.get(pending))
                persist(remaining)
                return Result.retry()
            }

            if (response !in 200..299) {
                for (pending in index until queue.length()) remaining.put(queue.get(pending))
                persist(remaining)
                return if (response in 400..499) Result.failure() else Result.retry()
            }
        }
        persist(remaining)
        return Result.success()
    }

    private fun send(baseUrl: String, apiKey: String, token: String, event: JSONObject): Int {
        val body = JSONObject()
            .put("p_direction", event.getString("direction"))
            .put("p_observed_at", isoTimestamp(event.getLong("observed_at")))
            .put("p_client_event_id", event.getString("event_id"))
        return post(
            "$baseUrl/rest/v1/rpc/record_tenant_geofence_transition",
            apiKey,
            token,
            body,
        ).first
    }

    private fun refreshSession(baseUrl: String, apiKey: String): String? {
        val refreshToken = prefs.getString("refresh_token", null) ?: return null
        val (code, payload) = try {
            post(
                "$baseUrl/auth/v1/token?grant_type=refresh_token",
                apiKey,
                null,
                JSONObject().put("refresh_token", refreshToken),
            )
        } catch (_: IOException) {
            return null
        }
        if (code !in 200..299) return null
        val json = JSONObject(payload)
        val access = json.optString("access_token").takeIf { it.isNotBlank() } ?: return null
        val refresh = json.optString("refresh_token").takeIf { it.isNotBlank() } ?: refreshToken
        prefs.edit().putString("access_token", access).putString("refresh_token", refresh).apply()
        return access
    }

    /**
     * Executes an HTTP POST and returns (statusCode, body).
     *
     * @throws IOException if the connection fails (no network, DNS failure,
     *   timeout, etc.).  Callers must handle this and return [Result.retry].
     */
    private fun post(
        target: String,
        apiKey: String,
        token: String?,
        body: JSONObject,
    ): Pair<Int, String> {
        val connection = URL(target).openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", apiKey)
            if (token != null) connection.setRequestProperty("Authorization", "Bearer $token")
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            code to (stream?.bufferedReader()?.use { it.readText() } ?: "")
        } finally {
            connection.disconnect()
        }
    }

    private fun persist(events: JSONArray) {
        prefs.edit().putString("pending_events", events.toString()).apply()
    }

    private fun isoTimestamp(milliseconds: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(milliseconds))
}
