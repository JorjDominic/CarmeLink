package com.example.carmelitas_dormitory_system

import android.content.Context
import android.location.Location
import org.json.JSONArray
import kotlin.math.*

/** Exact polygon + official-gate verifier. The OS circle is only a wake-up hint. */
object TripwireCrossingVerifier {
    private const val MAX_ACCURACY_METERS = 35f
    private const val MAX_AGE_MILLIS = 120_000L
    private const val CANDIDATE_DIRECTION = "candidate_direction"
    private const val CANDIDATE_FIX_COUNT = "candidate_fix_count"
    private const val REQUIRED_MATCHING_FIXES = 2

    // Sampling policy only; accept() retains the existing crossing rules.
    fun needsPreciseSampling(context: Context, location: Location): Boolean {
        if (location.accuracy > 15f) return true
        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        if (prefs.getInt(CANDIDATE_FIX_COUNT, 0) > 0) return true
        val polygon = parsePolygon(prefs.getString("polygon", "[]"))
        if (polygon.size < 3) return true
        return polygon.indices.minOf { index ->
            pointToSegmentMeters(Point(location.latitude, location.longitude),
                polygon[index], polygon[(index + 1) % polygon.size])
        } <= 50.0
    }

    fun accept(context: Context, location: Location): String? {
        // Quality gate — reject stale or inaccurate fixes.
        if (location.accuracy < 0 || location.accuracy > MAX_ACCURACY_METERS) return null
        if (abs(System.currentTimeMillis() - location.time) > MAX_AGE_MILLIS) return null

        val prefs = context.getSharedPreferences(TripwireGeofenceManager.PREFS, Context.MODE_PRIVATE)
        val polygon = parsePolygon(prefs.getString("polygon", "[]"))
        // Polygon evaluation is the primary boundary test — it always runs
        // regardless of whether the virtual gate line is configured.
        if (polygon.size < 3) return null

        // Pending events represent the latest physical state, but are not
        // promoted to confirmed_direction until the server stores them.
        val previousDirection = prefs.getString(TripwireGeofenceManager.QUEUED_DIRECTION, null)
            ?: prefs.getString("confirmed_direction", null)

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

        prefs.edit()
            .putLong("last_latitude_bits", location.latitude.toBits())
            .putLong("last_longitude_bits", location.longitude.toBits())
            .putLong("last_location_at", location.time)
            .apply()

        if (previousDirection == null) {
            // Establish baseline — first fix after cold-start is not a crossing.
            prefs.edit()
                .putString("confirmed_direction", direction)
                .remove(CANDIDATE_DIRECTION)
                .remove(CANDIDATE_FIX_COUNT)
                .apply()
            return null
        }
        if (direction == previousDirection) {
            prefs.edit()
                .remove(CANDIDATE_DIRECTION)
                .remove(CANDIDATE_FIX_COUNT)
                .apply()
            return null // No crossing.
        }

        // A first fix on the opposite side may be a transient GPS jump. Require
        // a second consecutive accurate fix before recording either a normal
        // background crossing or post-force-stop state reconciliation.
        val previousCandidate = prefs.getString(CANDIDATE_DIRECTION, null)
        val candidateCount = if (previousCandidate == direction) {
            prefs.getInt(CANDIDATE_FIX_COUNT, 0) + 1
        } else {
            1
        }
        prefs.edit()
            .putString(CANDIDATE_DIRECTION, direction)
            .putInt(CANDIDATE_FIX_COUNT, candidateCount)
            .apply()
        if (candidateCount < REQUIRED_MATCHING_FIXES) return null
        prefs.edit()
            .remove(CANDIDATE_DIRECTION)
            .remove(CANDIDATE_FIX_COUNT)
            .apply()

        // The precise polygon result is authoritative. The optional gate region
        // is only an additional low-latency wake-up hint; requiring sparse
        // movement fixes to intersect that short segment discarded valid exits
        // when Android delivered a callback beyond the gate. Accuracy,
        // freshness, hysteresis, and duplicate checks still protect this event.
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

}
