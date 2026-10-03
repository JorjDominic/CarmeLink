package com.example.carmelitas_dormitory_system

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class MonitoringHealthWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("registered", false)) return Result.success()
        val url = prefs.getString("supabase_url", null) ?: return Result.failure()
        val key = prefs.getString("publishable_key", null) ?: return Result.failure()
        var token = prefs.getString("access_token", null) ?: return Result.retry()
        val available = prefs.getBoolean("monitoring_health_available", true)
        val reason = prefs.getString("monitoring_health_reason", null)
        val body = JSONObject().put("p_available", available).put("p_platform", "android")
        if (!available && reason != null) body.put("p_reason", reason)
        return try {
            var code = send(url, key, token, body)
            if (code == HttpURLConnection.HTTP_UNAUTHORIZED) {
                token = refresh(url, key, prefs.getString("refresh_token", null)) ?: return Result.retry()
                prefs.edit().putString("access_token", token).apply()
                code = send(url, key, token, body)
            }
            if (code in 200..299) {
                prefs.edit().putBoolean("monitoring_health_reported_available", available)
                    .putString("monitoring_health_reported_reason", reason).apply()
                Result.success()
            }
            else if (code == 401 || code >= 500) Result.retry() else Result.failure()
        } catch (_: Exception) { Result.retry() }
    }

    private fun send(url: String, key: String, token: String, body: JSONObject): Int {
        val connection = URL("$url/rest/v1/rpc/set_my_location_monitoring_health")
            .openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.outputStream.use { it.write(body.toString().toByteArray()) }
            connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    private fun refresh(url: String, key: String, refreshToken: String?): String? {
        if (refreshToken.isNullOrBlank()) return null
        val connection = URL("$url/auth/v1/token?grant_type=refresh_token").openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", key)
            connection.outputStream.use {
                it.write(JSONObject().put("refresh_token", refreshToken).toString().toByteArray())
            }
            if (connection.responseCode !in 200..299) null
            else {
                val session = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                session.optString("refresh_token").takeIf { it.isNotBlank() }?.let {
                    applicationContext.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
                        .edit().putString("refresh_token", it).apply()
                }
                session.optString("access_token").takeIf { it.isNotBlank() }
            }
        } finally { connection.disconnect() }
    }
}
