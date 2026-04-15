import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SafetyReview {
  final String? id;
  final String userId;
  final LatLng position;
  final String geohash;
  final SafetyReason reason;
  final String? description;
  final int severity; // 1-5
  final DateTime createdAt;
  final int upvotes;

  const SafetyReview({
    this.id,
    required this.userId,
    required this.position,
    required this.geohash,
    required this.reason,
    this.description,
    required this.severity,
    required this.createdAt,
    this.upvotes = 0,
  });

  /// The aggregated danger level based on severity.
  /// Used to determine circle color on the map.
  DangerLevel get dangerLevel {
    if (severity >= 4) return DangerLevel.red;
    if (severity >= 2) return DangerLevel.yellow;
    return DangerLevel.green;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'position': {
        'geopoint': GeoPoint(position.latitude, position.longitude),
        'geohash': geohash,
      },
      'reason': reason.name,
      'description': description,
      'severity': severity,
      'createdAt': Timestamp.fromDate(createdAt),
      'upvotes': upvotes,
    };
  }

  factory SafetyReview.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final posData = data['position'] as Map<String, dynamic>? ?? {};
    final gp = posData['geopoint'] as GeoPoint? ??
        const GeoPoint(28.6139, 77.2090);

    return SafetyReview(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      position: LatLng(gp.latitude, gp.longitude),
      geohash: posData['geohash'] as String? ?? '',
      reason: SafetyReason.values.byName(
        data['reason'] as String? ?? 'other',
      ),
      description: data['description'] as String?,
      severity: (data['severity'] as num?)?.toInt() ?? 1,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      upvotes: (data['upvotes'] as num?)?.toInt() ?? 0,
    );
  }
}

enum SafetyReason {
  badInfrastructure,
  poorLighting,
  sketchy,
  other,
}

extension SafetyReasonMeta on SafetyReason {
  String get label {
    switch (this) {
      case SafetyReason.badInfrastructure:
        return 'Bad Infrastructure';
      case SafetyReason.poorLighting:
        return 'Poor Lighting';
      case SafetyReason.sketchy:
        return 'Sketchy / Unsafe';
      case SafetyReason.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case SafetyReason.badInfrastructure:
        return '🚧';
      case SafetyReason.poorLighting:
        return '💡';
      case SafetyReason.sketchy:
        return '⚠️';
      case SafetyReason.other:
        return '📝';
    }
  }
}

enum DangerLevel { green, yellow, red }
