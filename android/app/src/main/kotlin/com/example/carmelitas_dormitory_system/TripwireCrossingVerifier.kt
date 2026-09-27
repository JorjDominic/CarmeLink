package com.example.carmelitas_dormitory_system

import android.content.Context
import android.location.Location
import org.json.JSONArray
import kotlin.math.*

/** Exact polygon + official-gate verifier. The OS circle is only a wake-up hint. */
object TripwireCrossingVerifier {
    private const val MAX_ACCURACY_METERS = 35f
    private const val MAX_AGE_MILLIS = 120_000L

    fun accept(context: Context, location: Location): String? {
        // Quality gate — reject stale or inaccurate fixes.
        if (location.accuracy < 0 || location.accuracy > MAX_ACCURACY_METERS) return null
        if (abs(System.currentTimeMillis() - location.time) > MAX_AGE_MILLIS) return null

        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        val polygon = parsePolygon(prefs.getString("polygon", "[]"))
        // Polygon evaluation is the primary boundary test — it always runs
        // regardless of whether the virtual gate line is configured.
        if (polygon.size < 3) return null

        val gateEnabled = prefs.getBoolean("gate_enabled", false)
        val previousDirection = prefs.getString("confirmed_direction", null)

        val inside = pointInPolygon(location.latitude, location.longitude, polygon)
        val edgeBuffer = prefs.getFloat("edge_buffer_meters", 3f).toDouble()
        val edgeDistance = polygon.indices.minOf { index ->
            pointToSegmentMeters(
                Point(location.latitude, location.longitude),
                polygon[index], polygon[(index + 1) % polygon.size],
            )
        }
        // Hysteresis: if within the edge buffer, keep the last known direction.
        val direction = when {
            edgeDistance <= edgeBuffer && previousDirection != null -> previousDirection
            inside -> "IN"
            else -> "OUT"
        }

        val previous = if (prefs.contains("last_latitude_bits") && prefs.contains("last_longitude_bits")) {
            Point(
                Double.fromBits(prefs.getLong("last_latitude_bits", 0)),
                Double.fromBits(prefs.getLong("last_longitude_bits", 0)),
            )
        } else null

        prefs.edit()
            .putLong("last_latitude_bits", location.latitude.toBits())
            .putLong("last_longitude_bits", location.longitude.toBits())
            .putLong("last_location_at", location.time)
            .apply()

        if (previousDirection == null) {
            // Establish baseline — first fix after cold-start is not a crossing.
            prefs.edit().putString("confirmed_direction", direction).apply()
            return null
        }
        if (direction == previousDirection) return null // No crossing.

        // Direction changed — now decide whether to commit it.
        if (gateEnabled && previous != null) {
            // Gate line is configured: additionally require the movement path
            // to cross (or come within tolerance of) the gate segment.
            // This prevents false triggers from someone stationary near the fence.
            val gateStart = Point(
                Double.fromBits(prefs.getLong("gate_start_latitude_bits", 0)),
                Double.fromBits(prefs.getLong("gate_start_longitude_bits", 0)),
            )
            val gateEnd = Point(
                Double.fromBits(prefs.getLong("gate_end_latitude_bits", 0)),
                Double.fromBits(prefs.getLong("gate_end_longitude_bits", 0)),
            )
            val tolerance = prefs.getFloat("gate_tolerance_meters", 15f).toDouble()
            val crossedGate = segmentDistanceMeters(
                previous, Point(location.latitude, location.longitude),
                gateStart, gateEnd,
            ) <= tolerance
            return if (crossedGate) direction else null
        }

        // No gate line configured (or no previous location to compute movement):
        // polygon direction change alone is sufficient evidence of a crossing.
        return direction
    }

    private data class Point(val lat: Double, val lng: Double)

    private fun parsePolygon(raw: String?): List<Point> = try {
        val array = JSONArray(raw ?: "[]")
        (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            Point(item.getDouble("lat"), item.getDouble("lng"))
        }
    } catch (_: Exception) { emptyList() }

    private fun pointInPolygon(lat: Double, lng: Double, polygon: List<Point>): Boolean {
        var inside = false
        var j = polygon.lastIndex
        for (i in polygon.indices) {
            val a = polygon[i]
            val b = polygon[j]
            if ((a.lat > lat) != (b.lat > lat) &&
                lng < (b.lng - a.lng) * (lat - a.lat) / (b.lat - a.lat) + a.lng
            ) inside = !inside
            j = i
        }
        return inside
    }

    private data class XY(val x: Double, val y: Double)
    private fun xy(point: Point, origin: Point): XY {
        val y = Math.toRadians(point.lat - origin.lat) * 6_371_000.0
        val x = Math.toRadians(point.lng - origin.lng) * 6_371_000.0 * cos(Math.toRadians(origin.lat))
        return XY(x, y)
    }

    private fun pointToSegmentMeters(point: Point, a: Point, b: Point): Double {
        val p = xy(point, a); val end = xy(b, a)
        val lengthSq = end.x * end.x + end.y * end.y
        val t = if (lengthSq == 0.0) 0.0 else ((p.x * end.x + p.y * end.y) / lengthSq).coerceIn(0.0, 1.0)
        return hypot(p.x - t * end.x, p.y - t * end.y)
    }

    private fun segmentDistanceMeters(a: Point, b: Point, c: Point, d: Point): Double {
        if (segmentsIntersect(xy(a, a), xy(b, a), xy(c, a), xy(d, a))) return 0.0
        return minOf(
            pointToSegmentMeters(a, c, d), pointToSegmentMeters(b, c, d),
            pointToSegmentMeters(c, a, b), pointToSegmentMeters(d, a, b),
        )
    }

    private fun segmentsIntersect(a: XY, b: XY, c: XY, d: XY): Boolean {
        fun cross(p: XY, q: XY, r: XY) = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        val abC = cross(a, b, c); val abD = cross(a, b, d)
        val cdA = cross(c, d, a); val cdB = cross(c, d, b)
        return abC * abD <= 0.0 && cdA * cdB <= 0.0
    }
}
