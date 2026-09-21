package com.example.carmelitas_dormitory_system

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "carmelitas/usage_stats")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasUsageStatsPermission())
                    "openPermissionSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getTodayUsage" -> if (hasUsageStatsPermission()) {
                        result.success(queryTodayUsage())
                    } else {
                        result.error("permission_denied", "Usage access has not been granted.", null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "carmelitas/tripwire_geofence")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "register" -> {
                        val latitude = call.argument<Double>("latitude")
                        val longitude = call.argument<Double>("longitude")
                        val radius = call.argument<Double>("radiusMeters")
                        val tenantId = call.argument<String>("tenantId")
                        val accessToken = call.argument<String>("accessToken")
                        val refreshToken = call.argument<String>("refreshToken")
                        val supabaseUrl = call.argument<String>("supabaseUrl")
                        val publishableKey = call.argument<String>("publishableKey")
                        val initialDirection = call.argument<String>("initialDirection")
                        if (latitude == null || longitude == null || radius == null || tenantId == null ||
                            accessToken == null || refreshToken == null || supabaseUrl == null ||
                            publishableKey == null
                        ) {
                            result.error("invalid_arguments", "Boundary and tenant are required.", null)
                        } else {
                            TripwireGeofenceManager(applicationContext).register(
                                latitude, longitude, radius.toFloat(), tenantId, initialDirection,
                                accessToken, refreshToken, supabaseUrl, publishableKey, result,
                            )
                        }
                    }
                    "unregister" -> TripwireGeofenceManager(applicationContext).unregister(result)
                    "consumePending" -> result.success(
                        TripwireGeofenceManager(applicationContext).consumePending(),
                    )
                    "acknowledge" -> {
                        val eventId = call.argument<String>("eventId")
                        if (eventId == null) {
                            result.error("invalid_arguments", "Event ID is required.", null)
                        } else {
                            TripwireGeofenceManager(applicationContext).acknowledge(eventId)
                            result.success(true)
                        }
                    }
                    "status" -> result.success(
                        TripwireGeofenceManager(applicationContext).status(),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun queryTodayUsage(): List<Map<String, Any>> {
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val apps = applicationContext.packageManager
        return manager.queryAndAggregateUsageStats(start, System.currentTimeMillis()).values
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .map { stat ->
                val label = try {
                    apps.getApplicationLabel(apps.getApplicationInfo(stat.packageName, 0)).toString()
                } catch (_: Exception) {
                    stat.packageName
                }
                mapOf(
                    "packageName" to stat.packageName,
                    "appName" to label,
                    "foregroundTime" to stat.totalTimeInForeground,
                )
            }
    }
}
