import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../models/buddy_request.dart';
import 'firestore_service.dart';

/// Real-time buddy matchmaking within a proximity radius.
class BuddyService extends ChangeNotifier {
  final FirestoreService _firestoreService;

  BuddyService(this._firestoreService);

  BuddyRequest? _activeRequest;
  BuddyRequest? _matchedBuddy;
  StreamSubscription<List<DocumentSnapshot<Map<String, dynamic>>>>?
      _searchSubscription;
  bool _isSearching = false;

  BuddyRequest? get activeRequest => _activeRequest;
  BuddyRequest? get matchedBuddy => _matchedBuddy;
  bool get isSearching => _isSearching;

  /// Start searching for a walking buddy.
  ///
  /// Creates a request in Firestore, then listens for nearby requests
  /// using geohash proximity queries.
  Future<void> startSearching({
    required String userId,
    required String displayName,
    required LatLng position,
  }) async {
    // Create GeoFirePoint for geohash
    final geoPoint = GeoFirePoint(
      GeoPoint(position.latitude, position.longitude),
    );

    final request = BuddyRequest(
      userId: userId,
      displayName: displayName,
      position: position,
      geohash: geoPoint.geohash,
      status: BuddyStatus.searching,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    // Save to Firestore
    final docId = await _firestoreService.createBuddyRequest(request);
    _activeRequest = BuddyRequest(
      id: docId,
      userId: request.userId,
      displayName: request.displayName,
      position: request.position,
      geohash: request.geohash,
      status: request.status,
      createdAt: request.createdAt,
      expiresAt: request.expiresAt,
    );
    _isSearching = true;
    notifyListeners();

    // Start listening for nearby buddy requests
    _listenForNearbyBuddies(
      userId: userId,
      center: GeoPoint(position.latitude, position.longitude),
      radiusKm: 1.0, // 1km radius
    );

    // Auto-expire after 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (_isSearching && _matchedBuddy == null) {
        cancelSearch();
      }
    });
  }

  /// Listen for other users searching within [radiusKm].
  void _listenForNearbyBuddies({
    required String userId,
    required GeoPoint center,
    required double radiusKm,
  }) {
    final collectionRef = FirebaseFirestore.instance
        .collection('buddy_requests');

    final geoRef = GeoCollectionReference<Map<String, dynamic>>(
      collectionRef,
    );

    _searchSubscription = geoRef
        .subscribeWithin(
          center: GeoFirePoint(center),
          radiusInKm: radiusKm,
          field: 'position',
          geopointFrom: (data) =>
              (data['position'] as Map<String, dynamic>)['geopoint']
                  as GeoPoint,
          strictMode: true,
        )
        .listen((docs) {
      // Filter out our own request and non-searching requests (client-side)
      final otherRequests = docs
          .where((doc) =>
              doc.data()?['userId'] != userId &&
              doc.data()?['status'] == BuddyStatus.searching.name)
          .toList();

      if (otherRequests.isNotEmpty) {
        // Match with the closest one
        final matchDoc = otherRequests.first;
        _handleMatch(matchDoc, userId);
      }
    });
  }

  /// Handle a match between two users.
  void _handleMatch(
    DocumentSnapshot<Map<String, dynamic>> matchDoc,
    String currentUserId,
  ) async {
    if (!_isSearching || _matchedBuddy != null) return;

    final matchedRequest = BuddyRequest.fromDoc(matchDoc);

    // Update both requests to 'matched'
    if (_activeRequest?.id != null) {
      await _firestoreService.updateBuddyRequestStatus(
        _activeRequest!.id!,
        status: BuddyStatus.matched,
        matchedWith: matchedRequest.userId,
      );
    }

    await _firestoreService.updateBuddyRequestStatus(
      matchDoc.id,
      status: BuddyStatus.matched,
      matchedWith: currentUserId,
    );

    _matchedBuddy = matchedRequest;
    _isSearching = false;
    _searchSubscription?.cancel();
    notifyListeners();
  }

  /// Cancel the current search.
  Future<void> cancelSearch() async {
    if (_activeRequest?.id != null) {
      await _firestoreService.cancelBuddyRequest(_activeRequest!.id!);
    }
    _isSearching = false;
    _matchedBuddy = null;
    _activeRequest = null;
    _searchSubscription?.cancel();
    notifyListeners();
  }

  /// Clear match state (after dismissing match UI).
  void clearMatch() {
    _matchedBuddy = null;
    _activeRequest = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    super.dispose();
  }
}
