package com.example.carmelitas_dormitory_system

import android.content.Context
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Authenticated native requests shared by upload and notification retries. */
class TripwireApi(context: Context) {
    private val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)

    fun post(path: String, body: JSONObject): Pair<Int, String> {
        val base = prefs.getString("supabase_url", null) ?: throw IOException("Missing server configuration")
        val key = prefs.getString("publishable_key", null) ?: throw IOException("Missing publishable key")
        var token = prefs.getString("access_token", null) ?: throw IOException("Missing session")
        var response = request("$base$path", key, token, body)
        if (response.first == 401) synchronized(AUTH_LOCK) {
            val latest = prefs.getString("access_token", token)!!
            token = if (latest != token) latest else {
                val refresh = prefs.getString("refresh_token", null) ?: return response
                val session = request("$base/auth/v1/token?grant_type=refresh_token", key, null,
                    JSONObject().put("refresh_token", refresh))
                if (session.first !in 200..299) return response
                val json = JSONObject(session.second)
                val access = json.optString("access_token").takeIf { it.isNotBlank() } ?: return response
                prefs.edit().putString("access_token", access)
                    .putString("refresh_token", json.optString("refresh_token", refresh)).commit()
                access
            }
            response = request("$base$path", key, token, body)
        }
        return response
    }

    private fun request(url: String, key: String, token: String?, body: JSONObject): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("apikey", key)
            if (token != null) connection.setRequestProperty("Authorization", "Bearer $token")
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            code to (stream?.bufferedReader()?.use { it.readText() } ?: "")
        } finally { connection.disconnect() }
    }

    companion object { private val AUTH_LOCK = Any() }
}
