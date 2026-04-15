import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BuddyRequest {
  final String? id;
  final String userId;
  final String displayName;
  final LatLng position;
  final String geohash;
  final BuddyStatus status;
  final String? matchedWith;
  final String? trailId;
  final DateTime createdAt;
  final DateTime expiresAt;

  const BuddyRequest({
    this.id,
    required this.userId,
    required this.displayName,
    required this.position,
    required this.geohash,
    this.status = BuddyStatus.searching,
    this.matchedWith,
    this.trailId,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  BuddyRequest copyWith({
    BuddyStatus? status,
    String? matchedWith,
    String? trailId,
  }) {
    return BuddyRequest(
      id: id,
      userId: userId,
      displayName: displayName,
      position: position,
      geohash: geohash,
      status: status ?? this.status,
      matchedWith: matchedWith ?? this.matchedWith,
      trailId: trailId ?? this.trailId,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'position': {
        'geopoint': GeoPoint(position.latitude, position.longitude),
        'geohash': geohash,
      },
      'status': status.name,
      'matchedWith': matchedWith,
      'trailId': trailId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory BuddyRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final posData = data['position'] as Map<String, dynamic>? ?? {};
    final gp = posData['geopoint'] as GeoPoint? ??
        const GeoPoint(28.6139, 77.2090);

    return BuddyRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Anonymous',
      position: LatLng(gp.latitude, gp.longitude),
      geohash: posData['geohash'] as String? ?? '',
      status: BuddyStatus.values.byName(
        data['status'] as String? ?? 'searching',
      ),
      matchedWith: data['matchedWith'] as String?,
      trailId: data['trailId'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(minutes: 5)),
    );
  }
}

enum BuddyStatus { searching, matched, expired, cancelled }
