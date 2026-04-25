import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/safety_review.dart';

/// Generates randomised walking trails using Google Directions API.
class TrailService {
  // IMPORTANT: Never hardcode API keys. Use package:flutter_dotenv to load from .env file
  static String get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static const String _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Generate a random walking trail near [center].
  ///
  /// Avoids areas within [avoidZones] (red-flagged safety reviews).
  /// [radiusMeters] controls how far waypoints can be from center (500–2000m).
  Future<GeneratedTrail?> generateTrail({
    required LatLng center,
    required List<SafetyReview> avoidZones,
    double radiusMeters = 1200,
    int waypointCount = 4,
  }) async {
    final rng = math.Random();
    final waypoints = <LatLng>[];

    // Generate random waypoints, filtering out danger zones
    int attempts = 0;
    while (waypoints.length < waypointCount && attempts < 50) {
      final point = _randomPointInRadius(center, radiusMeters, rng);

      // Check if point is within 100m of any red/yellow zone
      final isSafe = !avoidZones.any((review) {
        if (review.severity < 3) return false; // only avoid severe reviews
        final dist = _haversineDistance(
          point.latitude,
          point.longitude,
          review.position.latitude,
          review.position.longitude,
        );
        return dist < 150; // 150m exclusion zone
      });

      if (isSafe) {
        waypoints.add(point);
      }
      attempts++;
    }

    if (waypoints.length < 2) {
      debugPrint('Could not generate enough safe waypoints');
      return null;
    }

    // Build a round-trip: start → waypoints → back near start
    final routePoints = [center, ...waypoints, center];

    // Call Google Directions API
    return _fetchDirections(routePoints);
  }

  // ── Alternate Routes ──────────────────────────────────────────────────

  /// Generate 3 distinctly shaped walking trails for the user to choose from.
  ///
  /// Returns a list of 1–3 trails (fewer on partial API failure).
  /// Returns an empty list if all 3 fail.
  Future<List<GeneratedTrail>> generateAlternateTrails({
    required LatLng center,
    required double distanceKm,
    required List<SafetyReview> avoidZones,
  }) async {
    final rng = math.Random();
    final distMeters = distanceKm * 1000;

    // Empirically calibrated divisors for Indian urban road networks.
    // Walking paths are 1.5–2.5× longer than straight-line distance due to
    // road layout, one-ways, detours, and random waypoint ordering.
    // The Directions API also uses optimize:true to reorder waypoints
    // efficiently (see _fetchDirections).

    // ── Route 1: Out-and-Back (visually straight corridor) ──
    // 2 waypoints along same bearing → ~4.5R effective road distance
    final outBackRadius = distMeters / 4.5;
    final bearing = rng.nextDouble() * 360.0; // single random bearing
    final outBackWaypoints = <LatLng>[
      _pointAtBearingAndDistance(center, bearing, outBackRadius * 0.7),
      _pointAtBearingAndDistance(center, bearing, outBackRadius * 1.0),
    ];
    final outBackRoute = [center, ...outBackWaypoints, center];

    // ── Route 2: Broad Loop (wide circular journey) ──
    // 4 waypoints + optimize:true reorders into efficient loop → ~8R
    final loopRadius = distMeters / 8.0;
    final loopWaypoints = _generateSafeWaypoints(
      center: center,
      radiusMeters: loopRadius,
      count: 4,
      avoidZones: avoidZones,
      rng: rng,
    );
    final loopRoute = [center, ...loopWaypoints, center];

    // ── Route 3: Neighborhood Zig-Zag (dense, close to home) ──
    // Many waypoints in tight area → scale divisor with waypoint count
    final zigzagCount = math.max(3, (distanceKm * 1.5).ceil());
    final zigzagRadius = distMeters / ((zigzagCount + 1) * 1.8);
    final zigzagWaypoints = _generateSafeWaypoints(
      center: center,
      radiusMeters: zigzagRadius,
      count: zigzagCount,
      avoidZones: avoidZones,
      rng: rng,
    );
    final zigzagRoute = [center, ...zigzagWaypoints, center];

    // Fire all 3 API calls in parallel
    final results = await Future.wait([
      _fetchDirections(outBackRoute),
      _fetchDirections(loopRoute),
      _fetchDirections(zigzagRoute),
    ]);

    // Filter out nulls (failed calls) and return whatever succeeded
    return results.whereType<GeneratedTrail>().toList();
  }

  /// Generate [count] random waypoints within [radiusMeters] of [center],
  /// excluding points within 150m of severe safety reviews.
  List<LatLng> _generateSafeWaypoints({
    required LatLng center,
    required double radiusMeters,
    required int count,
    required List<SafetyReview> avoidZones,
    required math.Random rng,
  }) {
    final waypoints = <LatLng>[];
    int attempts = 0;
    while (waypoints.length < count && attempts < 50) {
      final point = _randomPointInRadius(center, radiusMeters, rng);

      final isSafe = !avoidZones.any((review) {
        if (review.severity < 3) return false;
        final dist = _haversineDistance(
          point.latitude,
          point.longitude,
          review.position.latitude,
          review.position.longitude,
        );
        return dist < 150;
      });

      if (isSafe) {
        waypoints.add(point);
      }
      attempts++;
    }

    // Fallback: if avoid-zone filtering was too aggressive, return what we have
    if (waypoints.length < 2) {
      debugPrint('Warning: only generated ${waypoints.length}/$count safe waypoints');
    }
    return waypoints;
  }

  /// Generate a LatLng at a specific [bearingDeg] (0–360°) and [distMeters]
  /// from [center]. Used for the Out-and-Back corridor strategy.
  LatLng _pointAtBearingAndDistance(
      LatLng center, double bearingDeg, double distMeters) {
    const R = 6371000.0; // Earth radius in meters
    final lat1 = _toRad(center.latitude);
    final lon1 = _toRad(center.longitude);
    final brng = _toRad(bearingDeg);
    final d = distMeters / R;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(d) +
          math.cos(lat1) * math.sin(d) * math.cos(brng),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(brng) * math.sin(d) * math.cos(lat1),
          math.cos(d) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(
      lat2 * 180 / math.pi,
      lon2 * 180 / math.pi,
    );
  }

  /// Call Google Directions API with walking mode.
  Future<GeneratedTrail?> _fetchDirections(List<LatLng> points) async {
    final origin = '${points.first.latitude},${points.first.longitude}';
    final destination = '${points.last.latitude},${points.last.longitude}';

    // Intermediate waypoints (excluding origin and destination)
    final waypointsParam = points
        .sublist(1, points.length - 1)
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final uri = Uri.parse(
      '$_directionsBaseUrl?'
      'origin=$origin'
      '&destination=$destination'
      '&waypoints=optimize:true|$waypointsParam'
      '&mode=walking'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        debugPrint('Directions API error: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;

      if (status != 'OK') {
        debugPrint('Directions API status: $status');
        return null;
      }

      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final overviewPolyline =
          route['overview_polyline']?['points'] as String? ?? '';
      final legs = route['legs'] as List<dynamic>? ?? [];

      // Sum up distance and duration across all legs
      double totalMeters = 0;
      int totalSeconds = 0;
      for (final leg in legs) {
        totalMeters +=
            ((leg as Map<String, dynamic>)['distance']?['value'] as num?)
                    ?.toDouble() ??
                0;
        totalSeconds +=
            ((leg)['duration']?['value'] as num?)?.toInt() ?? 0;
      }

      // Decode polyline into LatLng list
      final decodedPath = _decodePolyline(overviewPolyline);

      return GeneratedTrail(
        waypoints: decodedPath,
        encodedPolyline: overviewPolyline,
        distanceMeters: totalMeters,
        estimatedMinutes: (totalSeconds / 60).ceil(),
      );
    } catch (e) {
      debugPrint('Directions API exception: $e');
      return null;
    }
  }

  /// Generate a random LatLng within [radiusMeters] of [center].
  LatLng _randomPointInRadius(
      LatLng center, double radiusMeters, math.Random rng) {
    final radiusDegrees = radiusMeters / 111000;
    final u = rng.nextDouble();
    final v = rng.nextDouble();
    final w = radiusDegrees * math.sqrt(u);
    final t = 2 * math.pi * v;

    final x = w * math.cos(t);
    final y = w * math.sin(t) / math.cos(center.latitude * math.pi / 180);

    return LatLng(center.latitude + x, center.longitude + y);
  }

  /// Haversine distance in meters between two points.
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  /// Decode a Google encoded polyline string into LatLng points.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

/// Result from trail generation (before saving to Firestore).
class GeneratedTrail {
  final List<LatLng> waypoints;
  final String encodedPolyline;
  final double distanceMeters;
  final int estimatedMinutes;

  const GeneratedTrail({
    required this.waypoints,
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.estimatedMinutes,
  });
}
