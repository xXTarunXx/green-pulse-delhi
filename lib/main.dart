import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'screens/home_map_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/guilds_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'services/trail_service.dart';
import 'services/buddy_service.dart';
import 'services/safety_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Create shared services
  final firestoreService = FirestoreService();
  final authService = AuthService();

  try {
    await authService.ensureSignedIn();
  } catch (error) {
    debugPrint('Anonymous sign-in failed: $error');
  }

  final userId = authService.uid;
  if (userId != null) {
    try {
      await firestoreService.createOrUpdateUser(
        userId: userId,
        displayName: authService.displayName,
        email: authService.currentUser?.email ?? '',
        isAnonymous: authService.isAnonymous,
      );
    } catch (error) {
      debugPrint('User profile setup failed: $error');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<TrailService>(create: (_) => TrailService()),
        ChangeNotifierProvider<LocationService>(
          create: (_) => LocationService(),
        ),
        ChangeNotifierProvider<BuddyService>(
          create: (_) => BuddyService(firestoreService),
        ),
        ChangeNotifierProvider<SafetyService>(
          create: (_) => SafetyService(firestoreService),
        ),
      ],
      child: const GreenPulseApp(),
    ),
  );
}

// ─── Eco-Tech Color Tokens ───────────────────────────────────────────────────

class EcoColors {
  EcoColors._();

  // Primary greens
  static const Color seedGreen = Color(0xFF2E7D32);
  static const Color leafGreen = Color(0xFF43A047);
  static const Color mintGreen = Color(0xFF81C784);
  static const Color paleGreen = Color(0xFFC8E6C9);
  static const Color deepForest = Color(0xFF1B5E20);

  // Accent & surface
  static const Color limeAccent = Color(0xFFB2FF59);
  static const Color tealAccent = Color(0xFF00BFA5);
  static const Color surfaceLight = Color(0xFFF5FBF5);
  static const Color surfaceDark = Color(0xFF0D1F12);

  // Neutrals
  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF49454F);
  static const Color outline = Color(0xFFCAC4D0);
}

// ─── App Root ────────────────────────────────────────────────────────────────

class GreenPulseApp extends StatelessWidget {
  final Widget? homeOverride;

  const GreenPulseApp({super.key, this.homeOverride});

  @override
  Widget build(BuildContext context) {
    // Build Poppins text theme
    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.light().textTheme,
    );
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    // Material 3 color scheme from seed
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: EcoColors.seedGreen,
      brightness: Brightness.light,
      primary: EcoColors.seedGreen,
      onPrimary: Colors.white,
      primaryContainer: EcoColors.paleGreen,
      onPrimaryContainer: EcoColors.deepForest,
      secondary: EcoColors.tealAccent,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFB2DFDB),
      onSecondaryContainer: const Color(0xFF00251A),
      tertiary: EcoColors.limeAccent,
      surface: EcoColors.surfaceLight,
      onSurface: EcoColors.textPrimary,
      onSurfaceVariant: EcoColors.textSecondary,
      outline: EcoColors.outline,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: EcoColors.seedGreen,
      brightness: Brightness.dark,
      primary: EcoColors.mintGreen,
      onPrimary: EcoColors.deepForest,
      primaryContainer: EcoColors.deepForest,
      onPrimaryContainer: EcoColors.paleGreen,
      secondary: EcoColors.tealAccent,
      surface: EcoColors.surfaceDark,
      onSurface: const Color(0xFFE6E1E5),
    );

    return MaterialApp(
      title: 'Green-Pulse Delhi',
      debugShowCheckedModeBanner: false,

      // ─── Light Theme ─────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        textTheme: textTheme,
        scaffoldBackgroundColor: EcoColors.surfaceLight,

        // AppBar
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: EcoColors.surfaceLight,
          foregroundColor: EcoColors.textPrimary,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: EcoColors.seedGreen,
            fontSize: 20,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),

        // NavigationBar (bottom)
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          elevation: 4,
          backgroundColor: EcoColors.surfaceLight,
          indicatorColor: EcoColors.paleGreen,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: EcoColors.seedGreen,
                size: 26,
              );
            }
            return IconThemeData(
              color: EcoColors.textSecondary.withValues(alpha: 0.7),
              size: 24,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return textTheme.labelSmall?.copyWith(
                color: EcoColors.seedGreen,
                fontWeight: FontWeight.w600,
              );
            }
            return textTheme.labelSmall?.copyWith(
              color: EcoColors.textSecondary.withValues(alpha: 0.7),
            );
          }),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        ),

        // Card
        cardTheme: CardThemeData(
          elevation: 1,
          shadowColor: EcoColors.seedGreen.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          surfaceTintColor: const Color(0xFFC8E6C9),
        ),

        // ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: EcoColors.seedGreen.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: textTheme.labelLarge,
          ),
        ),

        // FloatingActionButton
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: EcoColors.seedGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),

        // Chip
        chipTheme: ChipThemeData(
          backgroundColor: EcoColors.paleGreen.withValues(alpha: 0.5),
          labelStyle: textTheme.labelSmall?.copyWith(
            color: EcoColors.deepForest,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide.none,
        ),

        // Divider
        dividerTheme: DividerThemeData(
          color: EcoColors.outline.withValues(alpha: 0.3),
          thickness: 1,
        ),
      ),

      // ─── Dark Theme ──────────────────────────────────────────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
        scaffoldBackgroundColor: EcoColors.surfaceDark,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: EcoColors.surfaceDark,
          foregroundColor: const Color(0xFFE6E1E5),
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: EcoColors.mintGreen,
            fontSize: 20,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 72,
          elevation: 4,
          backgroundColor: Color(0xFF1A2E1D),
          indicatorColor: EcoColors.deepForest,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),

      themeMode: ThemeMode.light, // Default to light; switch via user pref

      home: homeOverride ?? const AuthGate(child: MainNavigator()),
    );
  }
}

// ─── Bottom-Nav Shell ────────────────────────────────────────────────────────

class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isRetrying = false;

  Future<void> _retrySetup() async {
    setState(() => _isRetrying = true);

    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();

    try {
      await authService.ensureSignedIn();
      await _ensureUserProfile(authService, firestoreService);
    } catch (error) {
      debugPrint('Auth retry failed: $error');
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _ensureUserProfile(
    AuthService authService,
    FirestoreService firestoreService,
  ) async {
    final userId = authService.uid;
    if (userId == null) return;

    await firestoreService.createOrUpdateUser(
      userId: userId,
      displayName: authService.displayName,
      email: authService.currentUser?.email ?? '',
      isAnonymous: authService.isAnonymous,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (!authService.isReady) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authService.uid != null) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Setting up your profile',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We could not finish anonymous sign-in. Check your connection and try again.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isRetrying ? null : _retrySetup,
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_isRetrying ? 'Trying again...' : 'Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeMapScreen(),
    ScannerScreen(),
    GuildsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AnimatedSwitcher for smooth page transitions
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),

      // Material 3 NavigationBar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        animationDuration: const Duration(milliseconds: 500),
        onDestinationSelected: (int index) {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco_rounded),
            label: 'Bio-Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Guilds',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Impact',
          ),
        ],
      ),
    );
  }
}
