import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Trail {
  final String? id;
  final String userId;
  final List<LatLng> waypoints;
  final String encodedPolyline;
  final double distanceMeters;
  final int estimatedMinutes;
  final TrailStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int pointsAwarded;
  final double? avgPaceMinPerKm;
  final String greenSpaceName;

  const Trail({
    this.id,
    required this.userId,
    required this.waypoints,
    required this.encodedPolyline,
    required this.distanceMeters,
    required this.estimatedMinutes,
    this.status = TrailStatus.active,
    this.startedAt,
    this.completedAt,
    this.pointsAwarded = 0,
    this.avgPaceMinPerKm,
    this.greenSpaceName = '',
  });

  Trail copyWith({
    String? id,
    TrailStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? pointsAwarded,
    double? avgPaceMinPerKm,
  }) {
    return Trail(
      id: id ?? this.id,
      userId: userId,
      waypoints: waypoints,
      encodedPolyline: encodedPolyline,
      distanceMeters: distanceMeters,
      estimatedMinutes: estimatedMinutes,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      avgPaceMinPerKm: avgPaceMinPerKm ?? this.avgPaceMinPerKm,
      greenSpaceName: greenSpaceName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'waypoints': waypoints
          .map((w) => GeoPoint(w.latitude, w.longitude))
          .toList(),
      'encodedPolyline': encodedPolyline,
      'distanceMeters': distanceMeters,
      'estimatedMinutes': estimatedMinutes,
      'status': status.name,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'pointsAwarded': pointsAwarded,
      'avgPaceMinPerKm': avgPaceMinPerKm,
      'greenSpaceName': greenSpaceName,
    };
  }

  factory Trail.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final rawWaypoints = data['waypoints'] as List<dynamic>? ?? [];

    return Trail(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      waypoints: rawWaypoints
          .map((gp) => LatLng(
                (gp as GeoPoint).latitude,
                gp.longitude,
              ))
          .toList(),
      encodedPolyline: data['encodedPolyline'] as String? ?? '',
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt() ?? 0,
      status: TrailStatus.values.byName(
        data['status'] as String? ?? 'active',
      ),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
      avgPaceMinPerKm: (data['avgPaceMinPerKm'] as num?)?.toDouble(),
      greenSpaceName: data['greenSpaceName'] as String? ?? '',
    );
  }

  /// Calculate points based on distance and pace.
  static int calculatePoints({
    required double distanceMeters,
    required double? avgPaceMinPerKm,
    required bool completedFull,
  }) {
    // Base: 10 pts per 100m
    final basePoints = (distanceMeters / 100) * 10;

    // Pace bonus: +50% if brisk walk (< 8 min/km)
    final paceBonus =
        (avgPaceMinPerKm != null && avgPaceMinPerKm < 8.0)
            ? basePoints * 0.5
            : 0.0;

    // Completion bonus
    final completionBonus = completedFull ? 100.0 : 0.0;

    return (basePoints + paceBonus + completionBonus).round();
  }
}

enum TrailStatus { active, completed, abandoned }
