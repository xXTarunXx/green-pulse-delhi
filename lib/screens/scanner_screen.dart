import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// ─── Mock species data ───────────────────────────────────────────────────────

class PlantSpecies {
  final String commonName;
  final String scientificName;
  final String family;
  final IconData icon;
  final Color accentColor;
  final String co2Impact;
  final String oxygenOutput;
  final int citizenPoints;
  final String funFact;
  final double rarity; // 0.0-1.0

  const PlantSpecies({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.icon,
    required this.accentColor,
    required this.co2Impact,
    required this.oxygenOutput,
    required this.citizenPoints,
    required this.funFact,
    required this.rarity,
  });
}

const List<PlantSpecies> _mockSpecies = [
  PlantSpecies(
    commonName: 'Neem Tree',
    scientificName: 'Azadirachta indica',
    family: 'Meliaceae',
    icon: Icons.park_rounded,
    accentColor: Color(0xFF2E7D32),
    co2Impact: '21 kg CO₂/year',
    oxygenOutput: '118 kg O₂/year',
    citizenPoints: 50,
    funFact: 'A single Neem tree can purify air in a 20m radius.',
    rarity: 0.3,
  ),
  PlantSpecies(
    commonName: 'Peepal Tree',
    scientificName: 'Ficus religiosa',
    family: 'Moraceae',
    icon: Icons.nature_rounded,
    accentColor: Color(0xFF388E3C),
    co2Impact: '37 kg CO₂/year',
    oxygenOutput: '1700 kg O₂/year',
    citizenPoints: 80,
    funFact: 'Releases oxygen 24/7, even at night — unique among trees.',
    rarity: 0.5,
  ),
  PlantSpecies(
    commonName: 'Gulmohar',
    scientificName: 'Delonix regia',
    family: 'Fabaceae',
    icon: Icons.local_florist_rounded,
    accentColor: Color(0xFFE65100),
    co2Impact: '15 kg CO₂/year',
    oxygenOutput: '95 kg O₂/year',
    citizenPoints: 60,
    funFact: 'Known as "Flame of the Forest" for its vivid red blossoms.',
    rarity: 0.6,
  ),
  PlantSpecies(
    commonName: 'Amaltas',
    scientificName: 'Cassia fistula',
    family: 'Fabaceae',
    icon: Icons.spa_rounded,
    accentColor: Color(0xFFF9A825),
    co2Impact: '12 kg CO₂/year',
    oxygenOutput: '78 kg O₂/year',
    citizenPoints: 55,
    funFact: 'Delhi\'s iconic golden cascades bloom every April–May.',
    rarity: 0.45,
  ),
  PlantSpecies(
    commonName: 'Ashoka Tree',
    scientificName: 'Saraca asoca',
    family: 'Fabaceae',
    icon: Icons.forest_rounded,
    accentColor: Color(0xFF6A1B9A),
    co2Impact: '10 kg CO₂/year',
    oxygenOutput: '65 kg O₂/year',
    citizenPoints: 90,
    funFact: 'An endangered species — scanning earns bonus conservation points.',
    rarity: 0.85,
  ),
];

// ─── Scanner Screen ──────────────────────────────────────────────────────────

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // Animations
  late AnimationController _scanlineController;
  late Animation<double> _scanlinePosition;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  late AnimationController _cornerController;
  late Animation<double> _cornerGlow;

  late AnimationController _cardController;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;

  // State
  bool _isScanning = true;
  bool _speciesFound = false;
  PlantSpecies? _discoveredSpecies;
  int _totalScans = 0;

  @override
  void initState() {
    super.initState();

    // Scanline sweep
    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _scanlinePosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanlineController, curve: Curves.easeInOut),
    );

    // Pulse (targeting reticle)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Corner bracket glow
    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _cornerGlow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _cornerController, curve: Curves.easeInOut),
    );

    // Discovery card entrance
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardSlide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraReady = true);
      } else {
        // Camera unavailable — fall back to simulated view
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      // Camera unavailable — fall back to simulated view
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanlineController.dispose();
    _pulseController.dispose();
    _cornerController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _triggerDiscovery() {
    if (_speciesFound) return;

    final rng = math.Random();
    final species = _mockSpecies[rng.nextInt(_mockSpecies.length)];

    setState(() {
      _isScanning = false;
      _speciesFound = true;
      _discoveredSpecies = species;
      _totalScans++;
    });

    _scanlineController.stop();
    _cardController.forward(from: 0);
  }

  void _resetScanner() {
    _cardController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _isScanning = true;
        _speciesFound = false;
        _discoveredSpecies = null;
      });
      _scanlineController.repeat(reverse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview / fallback ──────────────────────────────────
          _buildCameraLayer(),

          // ── Dark vignette ─────────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── AR scanning overlay ───────────────────────────────────────
          if (_isScanning) ...[
            // Scanline
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanlinePosition,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ScanlinePainter(
                      progress: _scanlinePosition.value,
                      color: const Color(0xFF69F0AE),
                    ),
                  );
                },
              ),
            ),

            // Corner brackets + targeting reticle
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseScale, _cornerGlow]),
                builder: (context, _) {
                  return Transform.scale(
                    scale: _pulseScale.value,
                    child: CustomPaint(
                      size: const Size(240, 240),
                      painter: _ViewfinderPainter(
                        glowAlpha: _cornerGlow.value,
                        color: const Color(0xFF69F0AE),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // ── Species-found flash ring  ─────────────────────────────────
          if (_speciesFound && _discoveredSpecies != null)
            Center(
              child: AnimatedBuilder(
                animation: _cardController,
                builder: (context, _) {
                  final progress = _cardController.value;
                  return Opacity(
                    opacity: (1.0 - progress).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.0 + progress * 0.6,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _discoveredSpecies!.accentColor
                                .withValues(alpha: 0.7),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Top status bar ────────────────────────────────────────────
          Positioned(
            top: mq.padding.top + 8,
            left: 16,
            right: 16,
            child: _TopStatusBar(
              isScanning: _isScanning,
              totalScans: _totalScans,
              colorScheme: cs,
            ),
          ),

          // ── Center scan prompt ────────────────────────────────────────
          if (_isScanning)
            Positioned(
              bottom: mq.size.height * 0.38,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF69F0AE),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Point at a plant to scan',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF69F0AE),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Discovery card ────────────────────────────────────────────
          if (_speciesFound && _discoveredSpecies != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _cardController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 180 * _cardSlide.value),
                    child: Opacity(
                      opacity: _cardFade.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: _DiscoveryCard(
                  species: _discoveredSpecies!,
                  onDismiss: _resetScanner,
                  colorScheme: cs,
                ),
              ),
            ),

          // ── Scan trigger button ───────────────────────────────────────
          if (_isScanning)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: _ScanButton(onTap: _triggerDiscovery),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_isCameraReady && _cameraController != null) {
      return Positioned.fill(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    // Fallback: simulated viewfinder background
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1F12),
              Color(0xFF1A2E1D),
              Color(0xFF0D1F12),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _SimulatedViewfinderPainter(),
        ),
      ),
    );
  }
}

// ─── Top Status Bar ──────────────────────────────────────────────────────────

class _TopStatusBar extends StatelessWidget {
  final bool isScanning;
  final int totalScans;
  final ColorScheme colorScheme;

  const _TopStatusBar({
    required this.isScanning,
    required this.totalScans,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Mode indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isScanning
                      ? const Color(0xFF69F0AE)
                      : const Color(0xFFFFA726),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isScanning
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFFFFA726))
                          .withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isScanning ? 'BIO-SCAN ACTIVE' : 'SPECIES FOUND',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Scans counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco_rounded, color: Color(0xFF69F0AE), size: 16),
              const SizedBox(width: 6),
              Text(
                '$totalScans scans',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Scan Button ─────────────────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF69F0AE), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF69F0AE).withValues(alpha: 0.25),
                  const Color(0xFF69F0AE).withValues(alpha: 0.08),
                ],
              ),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Color(0xFF69F0AE),
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Discovery Card ──────────────────────────────────────────────────────────

class _DiscoveryCard extends StatelessWidget {
  final PlantSpecies species;
  final VoidCallback onDismiss;
  final ColorScheme colorScheme;

  const _DiscoveryCard({
    required this.species,
    required this.onDismiss,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final rarityLabel = species.rarity >= 0.7
        ? 'Rare'
        : species.rarity >= 0.4
            ? 'Uncommon'
            : 'Common';
    final rarityColor = species.rarity >= 0.7
        ? const Color(0xFFAB47BC)
        : species.rarity >= 0.4
            ? const Color(0xFFFFA726)
            : const Color(0xFF66BB6A);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF5).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: species.accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: species.accentColor.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  species.accentColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                // Species icon badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        species.accentColor.withValues(alpha: 0.2),
                        species.accentColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(species.icon, color: species.accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species.commonName,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1B1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        species.scientificName,
                        style: tt.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF49454F),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rarity badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    rarityLabel,
                    style: tt.labelSmall?.copyWith(
                      color: rarityColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: species.accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(
                    icon: Icons.co2_rounded,
                    label: species.co2Impact,
                    color: species.accentColor,
                  ),
                  _divider(),
                  _StatChip(
                    icon: Icons.air_rounded,
                    label: species.oxygenOutput,
                    color: species.accentColor,
                  ),
                  _divider(),
                  _StatChip(
                    icon: Icons.family_restroom_rounded,
                    label: species.family,
                    color: species.accentColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Fun fact ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: Color(0xFFFFA726)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    species.funFact,
                    style: tt.bodySmall?.copyWith(
                      color: const Color(0xFF49454F),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Points banner + actions ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Row(
              children: [
                // Points earned
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          species.accentColor.withValues(alpha: 0.15),
                          species.accentColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 18, color: species.accentColor),
                        const SizedBox(width: 6),
                        Text(
                          '+${species.citizenPoints} Citizen Points',
                          style: tt.labelMedium?.copyWith(
                            color: species.accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Scan again
                FilledButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Scan Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: species.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: species.accentColor.withValues(alpha: 0.15),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF1C1B1F),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Scanline Painter ────────────────────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanlinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.18 + (size.height * 0.50) * progress;
    final margin = size.width * 0.12;

    // Glow behind scanline
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(margin, y - 20, size.width - margin * 2, 40))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRect(
      Rect.fromLTWH(margin, y - 20, size.width - margin * 2, 40),
      glowPaint,
    );

    // Sharp scanline
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.2, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(margin, y, size.width - margin * 2, 2));

    canvas.drawRect(
      Rect.fromLTWH(margin, y, size.width - margin * 2, 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) =>
      old.progress != progress;
}

// ─── Viewfinder Painter (corner brackets + crosshair) ────────────────────────

class _ViewfinderPainter extends CustomPainter {
  final double glowAlpha;
  final Color color;

  _ViewfinderPainter({required this.glowAlpha, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const cornerLen = 35.0;
    const radius = 12.0;

    final paint = Paint()
      ..color = color.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(cornerLen, 0),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - cornerLen, 0)
        ..lineTo(w - radius, 0)
        ..quadraticBezierTo(w, 0, w, radius)
        ..lineTo(w, cornerLen),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, h - cornerLen)
        ..lineTo(0, h - radius)
        ..quadraticBezierTo(0, h, radius, h)
        ..lineTo(cornerLen, h),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - cornerLen, h)
        ..lineTo(w - radius, h)
        ..quadraticBezierTo(w, h, w, h - radius)
        ..lineTo(w, h - cornerLen),
      paint,
    );

    // Subtle center crosshair
    final crossPaint = Paint()
      ..color = color.withValues(alpha: glowAlpha * 0.35)
      ..strokeWidth = 1;

    final cx = w / 2;
    final cy = h / 2;
    const crossSize = 14.0;
    const crossGap = 4.0;

    canvas.drawLine(
        Offset(cx - crossSize, cy), Offset(cx - crossGap, cy), crossPaint);
    canvas.drawLine(
        Offset(cx + crossGap, cy), Offset(cx + crossSize, cy), crossPaint);
    canvas.drawLine(
        Offset(cx, cy - crossSize), Offset(cx, cy - crossGap), crossPaint);
    canvas.drawLine(
        Offset(cx, cy + crossGap), Offset(cx, cy + crossSize), crossPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) =>
      old.glowAlpha != glowAlpha;
}

// ─── Simulated viewfinder background (when camera unavailable) ───────────────

class _SimulatedViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // fixed seed for consistent look

    // Faint foliage dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 2 + rng.nextDouble() * 6;
      dotPaint.color = Color.lerp(
        const Color(0xFF2E7D32),
        const Color(0xFF81C784),
        rng.nextDouble(),
      )!
          .withValues(alpha: 0.06 + rng.nextDouble() * 0.08);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
