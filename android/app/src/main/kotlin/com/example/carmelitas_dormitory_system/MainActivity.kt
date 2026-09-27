package com.example.carmelitas_dormitory_system

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                        val polygon = call.argument<List<Map<String, Any>>>("polygon")
                        if (latitude == null || longitude == null || radius == null || tenantId == null ||
                            accessToken == null || refreshToken == null || supabaseUrl == null ||
                            publishableKey == null
                        ) {
                            result.error("invalid_arguments", "Boundary and tenant are required.", null)
                        } else {
                            TripwireGeofenceManager(applicationContext).register(
                                latitude, longitude, radius.toFloat(), tenantId, initialDirection,
                                polygon ?: emptyList(),
                                call.argument<Double>("edgeBufferMeters")?.toFloat() ?: 3f,
                                call.argument<Boolean>("gateEnabled") ?: false,
                                call.argument<Double>("gateStartLatitude"),
                                call.argument<Double>("gateStartLongitude"),
                                call.argument<Double>("gateEndLatitude"),
                                call.argument<Double>("gateEndLongitude"),
                                call.argument<Double>("gateToleranceMeters")?.toFloat() ?: 15f,
                                call.argument<Int>("configVersion") ?: 1,
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

}
