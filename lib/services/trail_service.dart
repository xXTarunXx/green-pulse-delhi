import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/safety_review.dart';

/// Generates randomised walking trails using Google Directions API.
class TrailService {
  // IMPORTANT: Never hardcode API keys. Use package:flutter_dotenv to load from .env file
  static const String _apiKey = 'YOUR_API_KEY_HERE';

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
      '&waypoints=$waypointsParam'
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
