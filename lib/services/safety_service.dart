import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../models/safety_review.dart';
import 'firestore_service.dart';

/// Manages safety reviews — fetch, submit, aggregate into heatmap data.
class SafetyService extends ChangeNotifier {
  final FirestoreService _firestoreService;

  SafetyService(this._firestoreService);

  List<SafetyReview> _reviews = [];
  bool _isLoading = false;

  List<SafetyReview> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;

  /// Fetch all reviews from Firestore.
  Future<void> loadReviews() async {
    _isLoading = true;
    notifyListeners();

    try {
      _reviews = await _firestoreService.fetchReviews();
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Submit a new safety review.
  Future<void> submitReview({
    required String userId,
    required LatLng position,
    required SafetyReason reason,
    required int severity,
    String? description,
  }) async {
    final geoPoint = GeoFirePoint(
      GeoPoint(position.latitude, position.longitude),
    );

    final review = SafetyReview(
      userId: userId,
      position: position,
      geohash: geoPoint.geohash,
      reason: reason,
      severity: severity,
      description: description,
      createdAt: DateTime.now(),
    );

    await _firestoreService.submitReview(review);

    // Add locally for immediate UI update
    _reviews.insert(0, review);
    notifyListeners();
  }

  /// Get reviews aggregated by proximity for heatmap display.
  ///
  /// Groups nearby reviews and returns the worst severity for each cluster.
  List<HeatmapSpot> getHeatmapSpots() {
    final spots = <HeatmapSpot>[];

    // Simple clustering: group reviews within 50m of each other
    final processed = <int>{};

    for (int i = 0; i < _reviews.length; i++) {
      if (processed.contains(i)) continue;

      final cluster = [_reviews[i]];
      processed.add(i);

      for (int j = i + 1; j < _reviews.length; j++) {
        if (processed.contains(j)) continue;

        final dist = _distanceBetween(
          _reviews[i].position,
          _reviews[j].position,
        );

        if (dist < 50) {
          cluster.add(_reviews[j]);
          processed.add(j);
        }
      }

      // Aggregate: average position, max severity, count
      double avgLat = 0, avgLng = 0;
      int maxSeverity = 0;
      for (final r in cluster) {
        avgLat += r.position.latitude;
        avgLng += r.position.longitude;
        if (r.severity > maxSeverity) maxSeverity = r.severity;
      }
      avgLat /= cluster.length;
      avgLng /= cluster.length;

      spots.add(HeatmapSpot(
        position: LatLng(avgLat, avgLng),
        reviewCount: cluster.length,
        maxSeverity: maxSeverity,
        dangerLevel: _computeDangerLevel(cluster.length, maxSeverity),
      ));
    }

    return spots;
  }

  DangerLevel _computeDangerLevel(int count, int maxSeverity) {
    if (count >= 3 || maxSeverity >= 4) return DangerLevel.red;
    if (count >= 1 && maxSeverity >= 2) return DangerLevel.yellow;
    return DangerLevel.green;
  }

  /// Haversine distance in meters between two LatLng points.
  double _distanceBetween(LatLng a, LatLng b) {
    const double earthRadius = 6371000;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDlat = math.sin(dLat / 2);
    final sinDlng = math.sin(dLng / 2);
    final aCalc = sinDlat * sinDlat +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            sinDlng *
            sinDlng;
    final c = 2 * math.atan2(math.sqrt(aCalc), math.sqrt(1 - aCalc));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;
}

/// A clustered heatmap data point for map display.
class HeatmapSpot {
  final LatLng position;
  final int reviewCount;
  final int maxSeverity;
  final DangerLevel dangerLevel;

  const HeatmapSpot({
    required this.position,
    required this.reviewCount,
    required this.maxSeverity,
    required this.dangerLevel,
  });
}
