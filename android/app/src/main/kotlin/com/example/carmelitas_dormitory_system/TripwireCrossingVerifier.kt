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
    private const val CANDIDATE_STARTED_AT = "candidate_started_at"
    private const val CANDIDATE_LAST_FIX_AT = "candidate_last_fix_at"
    private const val CANDIDATE_ORIGIN_LATITUDE = "candidate_origin_latitude_bits"
    private const val CANDIDATE_ORIGIN_LONGITUDE = "candidate_origin_longitude_bits"
    private const val CANDIDATE_MOVING = "candidate_moving"
    private const val REQUIRED_MATCHING_FIXES = 2
    private const val MIN_CANDIDATE_FIX_SPACING_MILLIS = 8_000L
    private const val MIN_EDGE_BUFFER_METERS = 8.0
    private const val MIN_WALKING_SPEED_METERS_PER_SECOND = 0.5f

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
        val edgeBuffer = max(
            prefs.getFloat("edge_buffer_meters", 3f).toDouble(),
            MIN_EDGE_BUFFER_METERS,
        )
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

        val previousLocation = if (
            prefs.contains("last_latitude_bits") && prefs.contains("last_longitude_bits")
        ) Point(
            Double.fromBits(prefs.getLong("last_latitude_bits", 0L)),
            Double.fromBits(prefs.getLong("last_longitude_bits", 0L)),
        ) else null

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
                .remove(CANDIDATE_STARTED_AT)
                .remove(CANDIDATE_LAST_FIX_AT)
                .remove(CANDIDATE_ORIGIN_LATITUDE)
                .remove(CANDIDATE_ORIGIN_LONGITUDE)
                .remove(CANDIDATE_MOVING)
                .apply()
            return null
        }
        if (direction == previousDirection) {
            prefs.edit()
                .remove(CANDIDATE_DIRECTION)
                .remove(CANDIDATE_FIX_COUNT)
                .remove(CANDIDATE_STARTED_AT)
                .remove(CANDIDATE_LAST_FIX_AT)
                .remove(CANDIDATE_ORIGIN_LATITUDE)
                .remove(CANDIDATE_ORIGIN_LONGITUDE)
                .remove(CANDIDATE_MOVING)
                .apply()
            return null // No crossing.
        }

        // A first fix on the opposite side may be a transient GPS jump. Require
        // a second consecutive accurate fix before recording either a normal
        // background crossing or post-force-stop state reconciliation.
        val previousCandidate = prefs.getString(CANDIDATE_DIRECTION, null)
        val lastCandidateFixAt = prefs.getLong(CANDIDATE_LAST_FIX_AT, 0L)
        val sufficientlySeparated = location.time - lastCandidateFixAt >=
            MIN_CANDIDATE_FIX_SPACING_MILLIS
        val candidateCount = if (previousCandidate == direction && sufficientlySeparated) {
            prefs.getInt(CANDIDATE_FIX_COUNT, 0) + 1
        } else if (previousCandidate == direction) {
            prefs.getInt(CANDIDATE_FIX_COUNT, 1)
        } else {
            1
        }
        val newCandidate = previousCandidate != direction
        val candidateMoving = (!newCandidate && prefs.getBoolean(CANDIDATE_MOVING, false)) ||
            (location.hasSpeed() && location.speed >= MIN_WALKING_SPEED_METERS_PER_SECOND)
        val editor = prefs.edit()
            .putString(CANDIDATE_DIRECTION, direction)
            .putInt(CANDIDATE_FIX_COUNT, candidateCount)
            .putBoolean(CANDIDATE_MOVING, candidateMoving)
        if (newCandidate) {
            editor.putLong(CANDIDATE_STARTED_AT, System.currentTimeMillis())
            val origin = previousLocation ?: Point(location.latitude, location.longitude)
            editor.putLong(CANDIDATE_ORIGIN_LATITUDE, origin.lat.toBits())
                .putLong(CANDIDATE_ORIGIN_LONGITUDE, origin.lng.toBits())
        }
        if (newCandidate || sufficientlySeparated) {
            editor.putLong(CANDIDATE_LAST_FIX_AT, location.time)
        }
        editor.apply()
        if (candidateCount < REQUIRED_MATCHING_FIXES) return null

        // A stationary phone must not become OUT merely because indoor GPS
        // settles a few metres beyond the polygon. For departure, require
        // walking evidence or a movement segment through the configured gate.
        if (direction == "OUT" && !candidateMoving && !candidateCrossesGate(prefs, location)) {
            return null
        }
        prefs.edit()
            .remove(CANDIDATE_DIRECTION)
            .remove(CANDIDATE_FIX_COUNT)
            .remove(CANDIDATE_STARTED_AT)
            .remove(CANDIDATE_LAST_FIX_AT)
            .remove(CANDIDATE_ORIGIN_LATITUDE)
            .remove(CANDIDATE_ORIGIN_LONGITUDE)
            .remove(CANDIDATE_MOVING)
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

    private fun candidateCrossesGate(
        prefs: android.content.SharedPreferences,
        location: Location,
    ): Boolean {
        if (!prefs.getBoolean("gate_enabled", false)) return false
        if (!prefs.contains(CANDIDATE_ORIGIN_LATITUDE) ||
            !prefs.contains(CANDIDATE_ORIGIN_LONGITUDE)
        ) return false
        val origin = Point(
            Double.fromBits(prefs.getLong(CANDIDATE_ORIGIN_LATITUDE, 0L)),
            Double.fromBits(prefs.getLong(CANDIDATE_ORIGIN_LONGITUDE, 0L)),
        )
        val current = Point(location.latitude, location.longitude)
        val gateStart = Point(
            Double.fromBits(prefs.getLong("gate_start_latitude_bits", 0L)),
            Double.fromBits(prefs.getLong("gate_start_longitude_bits", 0L)),
        )
        val gateEnd = Point(
            Double.fromBits(prefs.getLong("gate_end_latitude_bits", 0L)),
            Double.fromBits(prefs.getLong("gate_end_longitude_bits", 0L)),
        )
        val tolerance = max(prefs.getFloat("gate_tolerance_meters", 3.75f).toDouble(), 8.0)
        return segmentDistanceMeters(origin, current, gateStart, gateEnd) <= tolerance
    }

    private fun segmentDistanceMeters(a: Point, b: Point, c: Point, d: Point): Double {
        if (segmentsIntersect(xy(a, a), xy(b, a), xy(c, a), xy(d, a))) return 0.0
        return minOf(
            pointToSegmentMeters(a, c, d), pointToSegmentMeters(b, c, d),
            pointToSegmentMeters(c, a, b), pointToSegmentMeters(d, a, b),
        )
    }

    private fun segmentsIntersect(a: XY, b: XY, c: XY, d: XY): Boolean {
        fun cross(p: XY, q: XY, r: XY) =
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        return cross(a, b, c) * cross(a, b, d) <= 0.0 &&
            cross(c, d, a) * cross(c, d, b) <= 0.0
    }

}
