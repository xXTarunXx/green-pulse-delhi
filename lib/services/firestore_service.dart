import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trail.dart';
import '../models/safety_review.dart';
import '../models/buddy_request.dart';

/// Central Firestore CRUD service.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Collection refs ─────────────────────────────────────────────

  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _trailsRef => _db.collection('trails');
  CollectionReference get _reviewsRef => _db.collection('safety_reviews');
  CollectionReference get _buddyRef => _db.collection('buddy_requests');

  // ─── User ────────────────────────────────────────────────────────

  Future<void> createOrUpdateUser({
    required String userId,
    required String displayName,
    required String email,
    bool isAnonymous = false,
  }) async {
    final userDoc = _usersRef.doc(userId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final profileUpdates = <String, dynamic>{
        'displayName': displayName,
        'email': email,
        'isAnonymous': isAnonymous,
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      if (snapshot.exists) {
        transaction.set(userDoc, profileUpdates, SetOptions(merge: true));
        return;
      }

      transaction.set(userDoc, {
        ...profileUpdates,
        'totalPoints': 0,
        'totalDistanceKm': 0.0,
        'trailsCompleted': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addPointsToUser(String userId, int points) async {
    await _usersRef.doc(userId).update({
      'totalPoints': FieldValue.increment(points),
    });
  }

  Future<void> incrementTrailsCompleted(String userId) async {
    await _usersRef.doc(userId).update({
      'trailsCompleted': FieldValue.increment(1),
    });
  }

  Future<void> addDistanceToUser(String userId, double meters) async {
    await _usersRef.doc(userId).update({
      'totalDistanceKm': FieldValue.increment(meters / 1000),
    });
  }

  // ─── Trails ──────────────────────────────────────────────────────

  Future<String> saveTrail(Trail trail) async {
    final docRef = await _trailsRef.add(trail.toMap());
    return docRef.id;
  }

  Future<void> updateTrailStatus(
    String trailId, {
    required TrailStatus status,
    DateTime? completedAt,
    int? pointsAwarded,
    double? avgPaceMinPerKm,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
    };
    if (completedAt != null) {
      updates['completedAt'] = Timestamp.fromDate(completedAt);
    }
    if (pointsAwarded != null) updates['pointsAwarded'] = pointsAwarded;
    if (avgPaceMinPerKm != null) {
      updates['avgPaceMinPerKm'] = avgPaceMinPerKm;
    }

    await _trailsRef.doc(trailId).update(updates);
  }

  // ─── Safety Reviews ──────────────────────────────────────────────

  Future<String> submitReview(SafetyReview review) async {
    final docRef = await _reviewsRef.add(review.toMap());
    return docRef.id;
  }

  /// Fetch all reviews (client-side filtering by viewport bounds).
  Future<List<SafetyReview>> fetchReviews() async {
    final snapshot = await _reviewsRef
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    return snapshot.docs.map((doc) => SafetyReview.fromDoc(doc)).toList();
  }

  /// Stream reviews for real-time updates on the map.
  Stream<List<SafetyReview>> streamReviews() {
    return _reviewsRef
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => SafetyReview.fromDoc(doc)).toList());
  }

  // ─── Buddy Requests ──────────────────────────────────────────────

  Future<String> createBuddyRequest(BuddyRequest request) async {
    final docRef = await _buddyRef.add(request.toMap());
    return docRef.id;
  }

  Future<void> updateBuddyRequestStatus(
    String requestId, {
    required BuddyStatus status,
    String? matchedWith,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
    };
    if (matchedWith != null) updates['matchedWith'] = matchedWith;
    await _buddyRef.doc(requestId).update(updates);
  }

  Future<void> cancelBuddyRequest(String requestId) async {
    await _buddyRef.doc(requestId).update({
      'status': BuddyStatus.cancelled.name,
    });
  }

  /// Stream active searching requests (for real-time matchmaking).
  Stream<List<BuddyRequest>> streamSearchingRequests() {
    return _buddyRef
        .where('status', isEqualTo: BuddyStatus.searching.name)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => BuddyRequest.fromDoc(doc)).toList());
  }
}
