import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Handles GPS location tracking and permissions.
class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  final List<LatLng> _trackedPath = [];
  bool _isTracking = false;
  double _totalDistanceMeters = 0;
  DateTime? _trackingStartTime;

  Position? get currentPosition => _currentPosition;
  List<LatLng> get trackedPath => List.unmodifiable(_trackedPath);
  bool get isTracking => _isTracking;
  double get totalDistanceMeters => _totalDistanceMeters;
  DateTime? get trackingStartTime => _trackingStartTime;

  /// Elapsed time since tracking started.
  Duration get elapsed {
    if (_trackingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_trackingStartTime!);
  }

  /// Average pace in minutes per kilometer.
  double? get avgPaceMinPerKm {
    if (_totalDistanceMeters < 10 || _trackingStartTime == null) return null;
    final minutes = elapsed.inSeconds / 60.0;
    final km = _totalDistanceMeters / 1000.0;
    return minutes / km;
  }

  /// Request location permissions and get current position.
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Get the user's current location once.
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    notifyListeners();
    return _currentPosition;
  }

  /// Start real-time GPS tracking for a walk.
  void startTracking() {
    _trackedPath.clear();
    _totalDistanceMeters = 0;
    _trackingStartTime = DateTime.now();
    _isTracking = true;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);

      // Calculate distance from last point
      if (_trackedPath.isNotEmpty) {
        final lastPoint = _trackedPath.last;
        final distance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        _totalDistanceMeters += distance;
      }

      _trackedPath.add(newPoint);
      _currentPosition = position;
      notifyListeners();
    });

    notifyListeners();
  }

  /// Stop GPS tracking and return summary.
  TrackingSummary stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    final summary = TrackingSummary(
      path: List.from(_trackedPath),
      distanceMeters: _totalDistanceMeters,
      durationSeconds: elapsed.inSeconds,
      avgPaceMinPerKm: avgPaceMinPerKm,
    );

    _trackingStartTime = null;
    notifyListeners();
    return summary;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

/// Summary of a completed tracking session.
class TrackingSummary {
  final List<LatLng> path;
  final double distanceMeters;
  final int durationSeconds;
  final double? avgPaceMinPerKm;

  const TrackingSummary({
    required this.path,
    required this.distanceMeters,
    required this.durationSeconds,
    this.avgPaceMinPerKm,
  });
}
