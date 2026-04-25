import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/trail.dart';
import '../models/safety_review.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/trail_service.dart';
import '../services/buddy_service.dart';
import '../services/safety_service.dart';
import '../services/firestore_service.dart';

// ─── Mock DDA park zones (static, always shown) ──────────────────────────────

class SafetyZone {
  final String id;
  final String label;
  final LatLng center;
  final double radiusMeters;
  final SafetyLevel level;

  const SafetyZone({
    required this.id,
    required this.label,
    required this.center,
    required this.radiusMeters,
    required this.level,
  });
}

enum SafetyLevel { safe, moderate, caution }

extension SafetyLevelColor on SafetyLevel {
  Color get color {
    switch (this) {
      case SafetyLevel.safe:
        return const Color(0xFF43A047);
      case SafetyLevel.moderate:
        return const Color(0xFFFFA726);
      case SafetyLevel.caution:
        return const Color(0xFFEF5350);
    }
  }

  String get label {
    switch (this) {
      case SafetyLevel.safe:
        return 'Safe';
      case SafetyLevel.moderate:
        return 'Moderate';
      case SafetyLevel.caution:
        return 'Caution';
    }
  }

  IconData get icon {
    switch (this) {
      case SafetyLevel.safe:
        return Icons.verified_user_rounded;
      case SafetyLevel.moderate:
        return Icons.shield_rounded;
      case SafetyLevel.caution:
        return Icons.warning_amber_rounded;
    }
  }
}

const List<SafetyZone> _mockZones = [
  SafetyZone(
      id: 'lodhi',
      label: 'Lodhi Garden',
      center: LatLng(28.5931, 77.2197),
      radiusMeters: 320,
      level: SafetyLevel.safe),
  SafetyZone(
      id: 'deer',
      label: 'Deer Park',
      center: LatLng(28.5648, 77.1939),
      radiusMeters: 220,
      level: SafetyLevel.safe),
  SafetyZone(
      id: 'nehru',
      label: 'Nehru Park',
      center: LatLng(28.5893, 77.1752),
      radiusMeters: 260,
      level: SafetyLevel.moderate),
  SafetyZone(
      id: 'sanjay_van',
      label: 'Sanjay Van',
      center: LatLng(28.5318, 77.1775),
      radiusMeters: 400,
      level: SafetyLevel.caution),
  SafetyZone(
      id: 'buddha',
      label: 'Buddha Jayanti Park',
      center: LatLng(28.6065, 77.1762),
      radiusMeters: 280,
      level: SafetyLevel.safe),
  SafetyZone(
      id: 'garden_five',
      label: 'Garden of Five Senses',
      center: LatLng(28.5133, 77.1961),
      radiusMeters: 200,
      level: SafetyLevel.moderate),
];

// ─── Home Map Screen ─────────────────────────────────────────────────────────

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;

  static const LatLng _delhiCenter = LatLng(28.5745, 77.1990);

  // Overlay toggles
  bool _showHeatmap = false;
  bool _showShadedPaths = false;

  // Trail state
  bool _isGeneratingTrail = false;
  List<GeneratedTrail> _alternateTrails = [];
  int? _selectedTrailIndex;
  GeneratedTrail? _generatedTrail; // populated on "Start Walk"
  String? _activeTrailId;
  bool _isWalking = false;
  double _distanceKm = 3.0; // slider value for distance sheet

  // Heatmap pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Bottom sheet animation
  late AnimationController _sheetController;
  late Animation<double> _sheetSlide;

  // Selected zone for info card
  SafetyZone? _selectedZone;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _sheetSlide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic),
    );

    // Load safety reviews on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SafetyService>().loadReviews();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // ── Map Overlays ─────────────────────────────────────────────────────

  Set<Circle> _buildMapCircles() {
    final circles = <Circle>{};

    // Static safety zones
    if (_showHeatmap) {
      circles.addAll(_mockZones.map((zone) {
        return Circle(
          circleId: CircleId(zone.id),
          center: zone.center,
          radius: zone.radiusMeters,
          fillColor: zone.level.color.withValues(alpha: 0.18),
          strokeColor: zone.level.color.withValues(alpha: 0.5),
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () => _onZoneTapped(zone),
        );
      }));
    }

    // Dynamic safety review heatmap spots
    final safetyService = context.read<SafetyService>();
    final spots = safetyService.getHeatmapSpots();
    for (final spot in spots) {
      final color = spot.dangerLevel == DangerLevel.red
          ? const Color(0xFFEF5350)
          : spot.dangerLevel == DangerLevel.yellow
              ? const Color(0xFFFFA726)
              : const Color(0xFF43A047);
      final radius = 40.0 + (spot.reviewCount * 15.0);

      circles.add(Circle(
        circleId: CircleId(
            'review_${spot.position.latitude}_${spot.position.longitude}'),
        center: spot.position,
        radius: radius,
        fillColor: color.withValues(alpha: 0.25),
        strokeColor: color.withValues(alpha: 0.6),
        strokeWidth: 2,
      ));
    }

    return circles;
  }

  Set<Marker> _buildMarkers() {
    return _mockZones.map((zone) {
      return Marker(
        markerId: MarkerId(zone.id),
        position: zone.center,
        infoWindow: InfoWindow(title: zone.label, snippet: zone.level.label),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          zone.level == SafetyLevel.safe
              ? BitmapDescriptor.hueGreen
              : zone.level == SafetyLevel.moderate
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueRed,
        ),
        onTap: () => _onZoneTapped(zone),
      );
    }).toSet();
  }

  // Route colors for alternate trails (mapped by index)
  static const List<Color> _routeColors = [
    Color(0xFF7BA7BC), // Dusty Blue  — Out-and-Back
    Color(0xFF8BA888), // Muted Sage  — Broad Loop
    Color(0xFFC4836A), // Terracotta  — Zig-Zag
  ];

  static const List<String> _routeLabels = [
    'Out-and-Back',
    'Broad Loop',
    'Zig-Zag',
  ];

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    // Alternate trails (selection phase)
    if (_alternateTrails.isNotEmpty) {
      for (int i = 0; i < _alternateTrails.length; i++) {
        final isSelected = _selectedTrailIndex == i;
        final hasSelection = _selectedTrailIndex != null;
        final color = i < _routeColors.length
            ? _routeColors[i]
            : _routeColors[i % _routeColors.length];

        polylines.add(Polyline(
          polylineId: PolylineId('alternate_$i'),
          points: _alternateTrails[i].waypoints,
          color: hasSelection && !isSelected
              ? color.withValues(alpha: 0.4)
              : color,
          width: isSelected ? 6 : 4,
          patterns: isSelected
              ? [] // solid line for selected
              : [PatternItem.dash(20), PatternItem.gap(10)],
          consumeTapEvents: true,
          onTap: () {
            setState(() => _selectedTrailIndex = i);
          },
        ));
      }
    }

    // Active walking trail polyline
    if (_generatedTrail != null && _alternateTrails.isEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('generated_trail'),
        points: _generatedTrail!.waypoints,
        color: const Color(0xFF00E676),
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    // User's walked path
    final locationService = context.read<LocationService>();
    if (locationService.trackedPath.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('walked_path'),
        points: locationService.trackedPath,
        color: const Color(0xFF2979FF),
        width: 6,
      ));
    }

    return polylines;
  }

  // ── Zone Info ────────────────────────────────────────────────────────

  void _onZoneTapped(SafetyZone zone) {
    setState(() => _selectedZone = zone);
    _sheetController.forward(from: 0);
  }

  void _dismissZoneCard() {
    _sheetController.reverse().then((_) {
      if (mounted) setState(() => _selectedZone = null);
    });
  }

  // ── Trail Generation (Alternate Routes) ──────────────────────────────

  void _showDistanceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        double localDistance = _distanceKm;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.route_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Distance',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'We\'ll find 3 unique routes for you',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Distance value
                  Text(
                    '${localDistance.toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20),
                    ),
                    child: Slider(
                      value: localDistance,
                      min: 1.0,
                      max: 10.0,
                      divisions: 18, // 0.5 km steps
                      label: '${localDistance.toStringAsFixed(1)} km',
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      onChanged: (v) {
                        setSheetState(() => localDistance = v);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 km',
                          style: Theme.of(context).textTheme.labelSmall),
                      Text('10 km',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Find Routes button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        _distanceKm = localDistance;
                        Navigator.pop(ctx);
                        _generateAlternateTrails();
                      },
                      icon: const Icon(Icons.explore_rounded, size: 20),
                      label: const Text('Find Routes'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateAlternateTrails() async {
    final locationService = context.read<LocationService>();
    final trailService = context.read<TrailService>();
    final safetyService = context.read<SafetyService>();

    setState(() => _isGeneratingTrail = true);

    // Get current position
    final position = await locationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📍 Location permission required'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _isGeneratingTrail = false);
      }
      return;
    }

    final userLatLng = LatLng(position.latitude, position.longitude);

    // Generate 3 alternate trails in parallel
    final trails = await trailService.generateAlternateTrails(
      center: userLatLng,
      distanceKm: _distanceKm,
      avoidZones: safetyService.reviews,
    );

    if (trails.isNotEmpty && mounted) {
      setState(() {
        _alternateTrails = trails;
        _selectedTrailIndex = null;
        _isGeneratingTrail = false;
      });

      // Show note if fewer than 3 routes returned
      if (trails.length < 3 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ℹ️ Found ${trails.length} of 3 routes. Some couldn\'t be generated.'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Zoom to show all trails
      if (_mapController != null) {
        final allPoints = trails.expand((t) => t.waypoints).toList();
        if (allPoints.isNotEmpty) {
          final bounds = _boundsFromPoints(allPoints);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Could not generate trails. Try again.'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isGeneratingTrail = false);
    }
  }

  void _startWalkFromSelection() {
    if (_selectedTrailIndex == null) return;
    setState(() {
      _generatedTrail = _alternateTrails[_selectedTrailIndex!];
      _alternateTrails = [];
      _selectedTrailIndex = null;
    });
    _startWalk(); // existing method, unchanged
  }

  void _clearAlternates() {
    setState(() {
      _alternateTrails = [];
      _selectedTrailIndex = null;
    });
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String? _requireUserId() {
    final userId = context.read<AuthService>().uid;
    if (userId != null) return userId;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Setting up your profile. Try again in a moment.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return null;
  }

  // ── Start/Stop Walk ──────────────────────────────────────────────────

  Future<void> _startWalk() async {
    final locationService = context.read<LocationService>();
    final firestoreService = context.read<FirestoreService>();
    final userId = _requireUserId();

    if (_generatedTrail == null || userId == null) return;

    // Save trail to Firestore
    final trail = Trail(
      userId: userId,
      waypoints: _generatedTrail!.waypoints,
      encodedPolyline: _generatedTrail!.encodedPolyline,
      distanceMeters: _generatedTrail!.distanceMeters,
      estimatedMinutes: _generatedTrail!.estimatedMinutes,
      status: TrailStatus.active,
      startedAt: DateTime.now(),
      greenSpaceName: 'Generated Trail',
    );

    final trailId = await firestoreService.saveTrail(trail);

    locationService.startTracking();
    setState(() {
      _isWalking = true;
      _activeTrailId = trailId;
    });
  }

  Future<void> _completeWalk() async {
    final locationService = context.read<LocationService>();
    final firestoreService = context.read<FirestoreService>();
    final userId = _requireUserId();

    if (userId == null) return;

    final summary = locationService.stopTracking();

    // Calculate points
    final completedFull = _generatedTrail != null &&
        summary.distanceMeters >= _generatedTrail!.distanceMeters * 0.8;

    final points = Trail.calculatePoints(
      distanceMeters: summary.distanceMeters,
      avgPaceMinPerKm: summary.avgPaceMinPerKm,
      completedFull: completedFull,
    );

    // Update trail in Firestore
    if (_activeTrailId != null) {
      await firestoreService.updateTrailStatus(
        _activeTrailId!,
        status: TrailStatus.completed,
        completedAt: DateTime.now(),
        pointsAwarded: points,
        avgPaceMinPerKm: summary.avgPaceMinPerKm,
      );

      await firestoreService.addPointsToUser(userId, points);
      await firestoreService.addDistanceToUser(userId, summary.distanceMeters);
      await firestoreService.incrementTrailsCompleted(userId);
    }

    setState(() {
      _isWalking = false;
      _activeTrailId = null;
    });

    if (mounted) {
      _showCompletionDialog(summary, points);
    }
  }

  void _showCompletionDialog(TrackingSummary summary, int points) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: Color(0xFFFFD54F), size: 28),
            SizedBox(width: 10),
            Text('Walk Complete! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompletionStat(
              icon: Icons.straighten_rounded,
              label: 'Distance',
              value: '${(summary.distanceMeters / 1000).toStringAsFixed(2)} km',
            ),
            const SizedBox(height: 10),
            _CompletionStat(
              icon: Icons.timer_rounded,
              label: 'Duration',
              value: '${(summary.durationSeconds / 60).toStringAsFixed(1)} min',
            ),
            const SizedBox(height: 10),
            if (summary.avgPaceMinPerKm != null)
              _CompletionStat(
                icon: Icons.speed_rounded,
                label: 'Pace',
                value: '${summary.avgPaceMinPerKm!.toStringAsFixed(1)} min/km',
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '+$points XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _generatedTrail = null);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Safety Review Submission ──────────────────────────────────────────

  void _showReportSheet(LatLng position) {
    final safetyService = context.read<SafetyService>();
    final userId = _requireUserId();

    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportAreaSheet(
        position: position,
        onSubmit: (reason, severity, description) async {
          await safetyService.submitReview(
            userId: userId,
            position: position,
            reason: reason,
            severity: severity,
            description: description,
          );
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Text('✅ Safety review submitted'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          if (mounted) setState(() {}); // Refresh circles
        },
      ),
    );
  }

  // ── Buddy Walk ───────────────────────────────────────────────────────

  Future<void> _toggleBuddyWalk() async {
    final buddyService = context.read<BuddyService>();
    final locationService = context.read<LocationService>();
    final authService = context.read<AuthService>();

    if (buddyService.isSearching) {
      await buddyService.cancelSearch();
      return;
    }

    final userId = _requireUserId();
    if (userId == null) return;

    final position = await locationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📍 Location needed for Buddy Walk'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    await buddyService.startSearching(
      userId: userId,
      displayName: authService.displayName,
      position: LatLng(position.latitude, position.longitude),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locationService = context.watch<LocationService>();
    final buddyService = context.watch<BuddyService>();

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _delhiCenter,
              zoom: 12.5,
            ),
            style: _ecoMapStyle,
            circles: _buildMapCircles(),
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onTap: (_) => _dismissZoneCard(),
            onLongPress: _showReportSheet,
          ),

          // ── Animated Heatmap Glow Overlay ───────────────────────
          if (_showHeatmap)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: HeatmapGlowPainter(
                        pulseValue: _pulseAnimation.value,
                        showPaths: _showShadedPaths,
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Top gradient fade ───────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 24,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface.withValues(alpha: 0.85),
                    cs.surface.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),


          // ── Right-side filter toggles ───────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            right: 16,
            child: _FilterBar(
              showHeatmap: _showHeatmap,
              showShadedPaths: _showShadedPaths,
              onHeatmapToggle: () =>
                  setState(() => _showHeatmap = !_showHeatmap),
              onShadedPathToggle: () =>
                  setState(() => _showShadedPaths = !_showShadedPaths),
              colorScheme: cs,
            ),
          ),

          // ── Legend ──────────────────────────────────────────────
          if (_showHeatmap)
            Positioned(
              bottom: _selectedZone != null ? 200 : (_isWalking ? 200 : 100),
              left: 16,
              child: AnimatedOpacity(
                opacity: _showHeatmap ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _LegendRow(),
              ),
            ),

          // ── Zone Info Card ──────────────────────────────────────
          if (_selectedZone != null)
            Positioned(
              bottom: 96,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _sheetSlide,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 120 * _sheetSlide.value),
                    child: Opacity(
                      opacity: 1.0 - _sheetSlide.value,
                      child: child,
                    ),
                  );
                },
                child: _ZoneInfoCard(
                  zone: _selectedZone!,
                  onDismiss: _dismissZoneCard,
                  colorScheme: cs,
                  textTheme: tt,
                ),
              ),
            ),

          // ── Walking Status Bar ──────────────────────────────────
          if (_isWalking)
            Positioned(
              bottom: 96,
              left: 16,
              right: 16,
              child: _WalkingStatusBar(
                locationService: locationService,
                onComplete: _completeWalk,
                cs: cs,
                tt: tt,
              ),
            ),

          // ── Alternate Route Selection Panel ────────────────────
          if (_alternateTrails.isNotEmpty && !_isWalking)
            Positioned(
              bottom: 96,
              left: 16,
              right: 16,
              child: _AlternateRoutePanel(
                trails: _alternateTrails,
                selectedIndex: _selectedTrailIndex,
                routeColors: _routeColors,
                routeLabels: _routeLabels,
                onSelect: (i) => setState(() => _selectedTrailIndex = i),
                onStartWalk: _startWalkFromSelection,
                onCancel: _clearAlternates,
                cs: cs,
                tt: tt,
              ),
            ),

          // ── Trail Preview Panel (active walk) ─────────────────
          if (_generatedTrail != null && !_isWalking && _alternateTrails.isEmpty)
            Positioned(
              bottom: 96,
              left: 16,
              right: 16,
              child: _TrailPreviewCard(
                trail: _generatedTrail!,
                onStart: _startWalk,
                onCancel: () => setState(() => _generatedTrail = null),
                cs: cs,
                tt: tt,
              ),
            ),

          // ── Buddy Match Banner ──────────────────────────────────
          if (buddyService.matchedBuddy != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 16,
              right: 80,
              child: _BuddyMatchBanner(
                buddyName: buddyService.matchedBuddy!.displayName,
                onDismiss: () => buddyService.clearMatch(),
                cs: cs,
                tt: tt,
              ),
            ),

          // ── Buddy Searching Indicator ───────────────────────────
          if (buddyService.isSearching)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 16,
              right: 80,
              child: _BuddySearchingBanner(cs: cs, tt: tt),
            ),
        ],
      ),

      // ── FAB Area ─────────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Generate Trail FAB
          if (!_isWalking && _generatedTrail == null && _alternateTrails.isEmpty)
            FloatingActionButton(
              heroTag: 'generate_trail',
              onPressed: _isGeneratingTrail ? null : _showDistanceSheet,
              backgroundColor: cs.primaryContainer,
              child: _isGeneratingTrail
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.route_rounded, color: cs.primary),
            ),
          const SizedBox(height: 12),
          // Buddy Walk FAB
          _BuddyWalkFAB(
            isActive: buddyService.isSearching,
            onPressed: _toggleBuddyWalk,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ─── Alternate Route Selection Panel ─────────────────────────────────────────

class _AlternateRoutePanel extends StatelessWidget {
  final List<GeneratedTrail> trails;
  final int? selectedIndex;
  final List<Color> routeColors;
  final List<String> routeLabels;
  final ValueChanged<int> onSelect;
  final VoidCallback onStartWalk;
  final VoidCallback onCancel;
  final ColorScheme cs;
  final TextTheme tt;

  const _AlternateRoutePanel({
    required this.trails,
    required this.selectedIndex,
    required this.routeColors,
    required this.routeLabels,
    required this.onSelect,
    required this.onStartWalk,
    required this.onCancel,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTrail =
        selectedIndex != null ? trails[selectedIndex!] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedIndex != null
              ? routeColors[selectedIndex!].withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(Icons.alt_route_rounded, color: cs.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose a Route',
                        style:
                            tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      selectedIndex != null
                          ? 'Tap "Start Walk" to begin'
                          : 'Tap a route on the map or below',
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: cs.onSurfaceVariant, size: 20),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Route type chips
          Row(
            children: List.generate(trails.length, (i) {
              final isSelected = selectedIndex == i;
              final color = i < routeColors.length
                  ? routeColors[i]
                  : routeColors[i % routeColors.length];
              final label = i < routeLabels.length
                  ? routeLabels[i]
                  : 'Route ${i + 1}';

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < trails.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Color dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: tt.labelSmall?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? color : cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(trails[i].distanceMeters / 1000).toStringAsFixed(1)} km',
                            style: tt.labelSmall?.copyWith(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Selected route details + Start Walk button
          if (selectedTrail != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: routeColors[selectedIndex!].withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(
                    label: 'Distance',
                    value:
                        '${(selectedTrail.distanceMeters / 1000).toStringAsFixed(1)} km',
                  ),
                  _MiniStat(
                    label: 'Est. Time',
                    value: '~${selectedTrail.estimatedMinutes} min',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStartWalk,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start Walk'),
                style: FilledButton.styleFrom(
                  backgroundColor: routeColors[selectedIndex!],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Trail Preview Card ──────────────────────────────────────────────────────

class _TrailPreviewCard extends StatelessWidget {
  final GeneratedTrail trail;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final ColorScheme cs;
  final TextTheme tt;

  const _TrailPreviewCard({
    required this.trail,
    required this.onStart,
    required this.onCancel,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route_rounded,
                    color: Color(0xFF00E676), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trail Generated!',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${(trail.distanceMeters / 1000).toStringAsFixed(1)} km · ~${trail.estimatedMinutes} min',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: cs.onSurfaceVariant, size: 20),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Start Walk'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Walking Status Bar ──────────────────────────────────────────────────────

class _WalkingStatusBar extends StatelessWidget {
  final LocationService locationService;
  final VoidCallback onComplete;
  final ColorScheme cs;
  final TextTheme tt;

  const _WalkingStatusBar({
    required this.locationService,
    required this.onComplete,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final distKm = locationService.totalDistanceMeters / 1000;
    final elapsed = locationService.elapsed;
    final pace = locationService.avgPaceMinPerKm;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF2979FF).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2979FF).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_walk_rounded,
                    color: Color(0xFF2979FF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Walking…',
                    style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2979FF))),
              ),
              // Live pulse dot
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2979FF),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                  label: 'Distance', value: '${distKm.toStringAsFixed(2)} km'),
              _MiniStat(
                  label: 'Time',
                  value:
                      '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}'),
              _MiniStat(
                  label: 'Pace',
                  value: pace != null
                      ? '${pace.toStringAsFixed(1)} min/km'
                      : '--'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Complete Walk'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10)),
      ],
    );
  }
}

// ─── Completion Dialog Stat ──────────────────────────────────────────────────

class _CompletionStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CompletionStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 10),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Buddy Match Banner ──────────────────────────────────────────────────────

class _BuddyMatchBanner extends StatelessWidget {
  final String buddyName;
  final VoidCallback onDismiss;
  final ColorScheme cs;
  final TextTheme tt;

  const _BuddyMatchBanner({
    required this.buddyName,
    required this.onDismiss,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43A047).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Buddy Found! 🎉',
                    style: tt.labelMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                Text(buddyName,
                    style: tt.labelSmall?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white70, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _BuddySearchingBanner extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;
  const _BuddySearchingBanner({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Searching for a walking buddy nearby…',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Report Area Bottom Sheet ────────────────────────────────────────────────

class _ReportAreaSheet extends StatefulWidget {
  final LatLng position;
  final Future<void> Function(
      SafetyReason reason, int severity, String? description) onSubmit;

  const _ReportAreaSheet({required this.position, required this.onSubmit});

  @override
  State<_ReportAreaSheet> createState() => _ReportAreaSheetState();
}

class _ReportAreaSheetState extends State<_ReportAreaSheet> {
  SafetyReason _selectedReason = SafetyReason.badInfrastructure;
  int _severity = 3;
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('⚠️ Report This Area',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Help others stay safe by flagging issues',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Reason chips
          Text('Reason',
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SafetyReason.values.map((reason) {
              final isSelected = reason == _selectedReason;
              return ChoiceChip(
                label: Text('${reason.icon} ${reason.label}'),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedReason = reason),
                selectedColor: cs.primaryContainer,
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Severity slider
          Text('Severity: $_severity / 5',
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          Slider(
            value: _severity.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: _severity >= 4
                ? const Color(0xFFEF5350)
                : _severity >= 2
                    ? const Color(0xFFFFA726)
                    : const Color(0xFF43A047),
            onChanged: (v) => setState(() => _severity = v.round()),
          ),
          const SizedBox(height: 12),

          // Description
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Optional description…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      await widget.onSubmit(
                        _selectedReason,
                        _severity,
                        _descController.text.isEmpty
                            ? null
                            : _descController.text,
                      );
                    },
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isSubmitting ? 'Submitting…' : 'Submit Report'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Right-side Filter Buttons ───────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool showHeatmap;
  final bool showShadedPaths;
  final VoidCallback onHeatmapToggle;
  final VoidCallback onShadedPathToggle;
  final ColorScheme colorScheme;

  const _FilterBar({
    required this.showHeatmap,
    required this.showShadedPaths,
    required this.onHeatmapToggle,
    required this.onShadedPathToggle,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterIcon(
              icon: Icons.layers_rounded,
              tooltip: 'Safety Heatmap',
              isActive: showHeatmap,
              activeColor: colorScheme.primary,
              onTap: onHeatmapToggle,
              colorScheme: colorScheme),
          const SizedBox(height: 4),
          _FilterIcon(
              icon: Icons.park_rounded,
              tooltip: 'Shaded Paths',
              isActive: showShadedPaths,
              activeColor: const Color(0xFF66BB6A),
              onTap: onShadedPathToggle,
              colorScheme: colorScheme),
        ],
      ),
    );
  }
}

class _FilterIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _FilterIcon({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon,
                size: 22,
                color: isActive ? activeColor : colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// ─── Legend Row ───────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: SafetyLevel.safe.color, label: 'Safe'),
          const SizedBox(width: 12),
          _LegendDot(color: SafetyLevel.moderate.color, label: 'Moderate'),
          const SizedBox(width: 12),
          _LegendDot(color: SafetyLevel.caution.color, label: 'Caution'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Zone Info Card ──────────────────────────────────────────────────────────

class _ZoneInfoCard extends StatelessWidget {
  final SafetyZone zone;
  final VoidCallback onDismiss;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ZoneInfoCard({
    required this.zone,
    required this.onDismiss,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final safetyColor = zone.level.color;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: safetyColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: safetyColor.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: safetyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(zone.level.icon, color: safetyColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.label,
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: safetyColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${zone.level.label} Zone',
                            style: textTheme.bodySmall?.copyWith(
                                color: safetyColor,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: colorScheme.onSurfaceVariant, size: 20),
                  onPressed: onDismiss,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                      icon: Icons.directions_walk_rounded,
                      value: '${(zone.radiusMeters / 100).round()} min',
                      label: 'Walk',
                      color: colorScheme.primary),
                  Container(
                      width: 1,
                      height: 28,
                      color: colorScheme.outline.withValues(alpha: 0.2)),
                  _StatItem(
                      icon: Icons.people_alt_rounded,
                      value: '${12 + zone.id.length}',
                      label: 'Visitors',
                      color: colorScheme.primary),
                  Container(
                      width: 1,
                      height: 28,
                      color: colorScheme.outline.withValues(alpha: 0.2)),
                  _StatItem(
                      icon: Icons.air_rounded,
                      value: 'AQI ${80 + zone.id.length * 5}',
                      label: 'Air',
                      color: colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatItem(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10)),
      ],
    );
  }
}

// ─── Buddy Walk FAB ──────────────────────────────────────────────────────────

class _BuddyWalkFAB extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;
  const _BuddyWalkFAB({required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        heroTag: 'buddy_walk',
        elevation: isActive ? 8 : 4,
        backgroundColor: isActive ? cs.tertiary : cs.primary,
        foregroundColor: isActive ? cs.onSurface : cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Icon(
              isActive ? Icons.close_rounded : Icons.person_add_alt_1_rounded,
              key: ValueKey(isActive)),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(isActive ? 'Cancel' : 'Buddy Walk',
              key: ValueKey(isActive),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─── Heatmap Glow Custom Painter ─────────────────────────────────────────────

class HeatmapGlowPainter extends CustomPainter {
  final double pulseValue;
  final bool showPaths;
  HeatmapGlowPainter({required this.pulseValue, this.showPaths = false});

  @override
  void paint(Canvas canvas, Size size) {
    _drawGlowCircle(canvas, Offset(size.width * 0.35, size.height * 0.32),
        55 * pulseValue, const Color(0xFF43A047), 0.20 * pulseValue);
    _drawGlowCircle(canvas, Offset(size.width * 0.55, size.height * 0.45),
        45 * pulseValue, const Color(0xFF43A047), 0.16 * pulseValue);
    _drawGlowCircle(canvas, Offset(size.width * 0.72, size.height * 0.38),
        40 * pulseValue, const Color(0xFFFFA726), 0.18 * pulseValue);
    _drawGlowCircle(canvas, Offset(size.width * 0.28, size.height * 0.62),
        50 * pulseValue, const Color(0xFFEF5350), 0.14 * pulseValue);
    _drawGlowCircle(canvas, Offset(size.width * 0.60, size.height * 0.68),
        35 * pulseValue, const Color(0xFF66BB6A), 0.15 * pulseValue);
    if (showPaths) _drawShadedPath(canvas, size);
  }

  void _drawGlowCircle(
      Canvas canvas, Offset center, double radius, Color color, double alpha) {
    canvas.drawCircle(
        center,
        radius * 1.6,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawCircle(
        center,
        radius * 0.5,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  void _drawShadedPath(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.3,
          size.width * 0.45, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.52,
          size.width * 0.65, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.48,
          size.width * 0.8, size.height * 0.55);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF4CAF50).withValues(alpha: 0.15)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF81C784).withValues(alpha: 0.08)
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
  }

  @override
  bool shouldRepaint(covariant HeatmapGlowPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.showPaths != showPaths;
}

// ─── Custom map style ────────────────────────────────────────────────────────

const String _ecoMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f0f5f0"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#4a6741"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#e8f0e8"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#d4e5d4"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c8e6c9"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#a8d5a8"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#2e7d32"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';
