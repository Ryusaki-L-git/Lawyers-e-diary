import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ld_logo.dart';
import 'widgets/app_palette.dart';
import 'services/led_id_allocation_service.dart';

/// The screen the application should open on launch.
enum StartupDestination {
  /// No valid session exists; the sign-in flow is required.
  login,

  /// The session is valid but the professional profile is not complete.
  welcome,

  /// The session is valid and the professional profile is complete.
  home,
}

/// Resolves the launch destination from the authoritative authentication state.
///
/// [hasAuthenticatedUser] must reflect the Firebase Authentication session,
/// which is the single source of truth for "is this user signed in".
///
/// [profileCompleted] is true only when the user's profile document confirmed
/// that the professional profile has been completed.
///
/// A locally stored preference is deliberately not part of this decision.
/// A stale or missing local flag must never be able to sign a valid user
/// out, and it must never be able to grant access to a signed-out user.
StartupDestination resolveStartupDestination({
  required bool hasAuthenticatedUser,
  required bool profileCompleted,
}) {
  if (!hasAuthenticatedUser) {
    return StartupDestination.login;
  }
  return profileCompleted
      ? StartupDestination.home
      : StartupDestination.welcome;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // MODERN LEGAL EDITORIAL THEME
  // ============================================================

  static const Color _background = Color(0xFFF7F5F2);

  static const Color _primaryGreen = Color(0xFF1F3D2B);

  static const Color _gold = Color(0xFFCCA046);

  static const Color _textDark = Color(0xFF1A1A1A);

  static const Color _textMuted = Color(0xFF6B665E);

  // ============================================================
  // ANIMATION
  // ============================================================

  late final AnimationController _entryController;
  late final AnimationController _loadingController;
  late final AnimationController _exitController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentFade;
  late final Animation<double> _contentOffset;

  String? _nextRoute;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _logoFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.28, 1.0, curve: Curves.easeOut),
    );

    _contentOffset = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.28, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entryController.forward();

    _startApp();
  }

  // ============================================================
  // STARTUP
  // ============================================================

  Future<void> _startApp() async {
    final Stopwatch startupTimer = Stopwatch()..start();

    final String routeToPush = await _determineStartupRoute();

    startupTimer.stop();

    const Duration minimumSplashDuration = Duration(seconds: 2);

    if (startupTimer.elapsed < minimumSplashDuration) {
      final Duration remainingTime =
          minimumSplashDuration - startupTimer.elapsed;

      await Future.delayed(remainingTime);
    }

    if (!mounted) return;

    _nextRoute = routeToPush;

    await _playExitAndNavigate();
  }

  // ============================================================
  // STARTUP ROUTING
  // ============================================================

  Future<String> _determineStartupRoute() async {
    // Firebase Authentication is the source of truth for the session. The
    // platform SDK restores a persisted session asynchronously, so
    // `currentUser` is briefly null on a cold start even when a valid
    // session exists on disk. Waiting for the restored state avoids sending
    // a returning user back to the sign-in screen.
    final User? user = await _awaitRestoredUser();

    if (user == null) {
      return '/login';
    }

    // Profile completion. A transient read failure must not sign the user
    // out, so the authenticated app is opened instead.
    bool profileCompleted = false;
    try {
      final DocumentSnapshot<Map<String, dynamic>> profileSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 10));

      final profileData = profileSnapshot.data() ?? <String, dynamic>{};
      profileCompleted = profileData['profileCompleted'] == true;

      // If onboarding is complete but the server could not assign an ID
      // earlier, retry in the background. The profile stream updates the
      // visible ID automatically once the gateway commits it.
      final existingLedId = profileData['ledId'];
      final profileName = profileData['name'];
      if (profileCompleted &&
          (existingLedId is! String || existingLedId.trim().isEmpty) &&
          profileName is String &&
          profileName.trim().isNotEmpty) {
        unawaited(LedIdAllocationService().allocateWithRetries(user));
      }
    } catch (error) {
      debugPrint(
        'Startup: the profile could not be read; opening the app. $error',
      );
      return '/home';
    }

    switch (resolveStartupDestination(
      hasAuthenticatedUser: true,
      profileCompleted: profileCompleted,
    )) {
      case StartupDestination.login:
        return '/login';
      case StartupDestination.welcome:
        return '/welcome';
      case StartupDestination.home:
        return '/home';
    }
  }

  /// Waits for Firebase Authentication to publish the restored session.
  ///
  /// The platform SDK loads the persisted session asynchronously, so
  /// `currentUser` can be null for a short window after
  /// `Firebase.initializeApp()` even when the user is still signed in.
  /// The auth state stream publishes the restored user once that work
  /// completes, so it is the reliable signal to wait for.
  Future<User?> _awaitRestoredUser() async {
    final FirebaseAuth auth = FirebaseAuth.instance;

    try {
      final User? restored = await auth.authStateChanges().first.timeout(
        const Duration(seconds: 20),
        onTimeout: () => auth.currentUser,
      );
      if (restored != null) {
        return restored;
      }
    } catch (error) {
      debugPrint('Startup: the auth state could not be read. $error');
    }

    // The stream reported no session. Give the delegate a brief grace
    // period to publish a restored user, then report the truth.
    for (int attempt = 0; attempt < 10; attempt++) {
      final User? current = auth.currentUser;
      if (current != null) {
        return current;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return auth.currentUser;
  }

  // ============================================================
  // EXIT
  // ============================================================

  Future<void> _playExitAndNavigate() async {
    if (!mounted) return;

    try {
      await _exitController.forward().orCancel;
    } catch (_) {
      return;
    }

    if (!mounted || _nextRoute == null) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(_nextRoute!);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _entryController.dispose();
    _loadingController.dispose();
    _exitController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entryController, _exitController]),
        builder: (context, child) {
          final double exitProgress = Curves.easeInOutCubic.transform(
            _exitController.value,
          );

          final double exitOpacity = 1.0 - exitProgress;

          final double exitScale = 1.0 - (exitProgress * 0.025);

          final double exitOffset = exitProgress * -14.0;

          return Opacity(
            opacity: exitOpacity,
            child: Transform.translate(
              offset: Offset(0, exitOffset),
              child: Transform.scale(scale: exitScale, child: child),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _EditorialBackground(),

            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ==================================================
                      // MARK
                      // ==================================================

                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: const _LogoContainer(),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // WORDMARK
                      // ==================================================
                      FadeTransition(
                        opacity: _contentFade,
                        child: AnimatedBuilder(
                          animation: _contentOffset,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _contentOffset.value),
                              child: child,
                            );
                          },
                          child: Column(
                            children: [
                              Text(
                                "LAWYER'S",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTypography.heading,
                                  color: _primaryGreen,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.0,
                                  height: 1.0,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                'E-DIARY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTypography.heading,
                                  color: _textDark,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3.0,
                                  height: 1.0,
                                ),
                              ),

                              SizedBox(height: 18),

                              SizedBox(
                                width: 42,
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: _gold,
                                ),
                              ),

                              SizedBox(height: 17),

                              Text(
                                'ORGANISE  •  MANAGE  •  WIN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 46),

                      // ==================================================
                      // LOADING
                      // ==================================================
                      FadeTransition(
                        opacity: _contentFade,
                        child: AnimatedBuilder(
                          animation: _loadingController,
                          builder: (context, child) {
                            return _GoldLoadingLine(
                              progress: _loadingController.value,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ============================================================
            // BOTTOM LABEL
            // ============================================================
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: FadeTransition(
                opacity: _contentFade,
                child: const Text(
                  'LEGAL CASE MANAGEMENT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================
// LOGO CONTAINER
// ========================================================================

class _LogoContainer extends StatelessWidget {
  const _LogoContainer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Center(
        child: Container(
          width: 116,
          height: 116,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5DFD7), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10111716),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const LawFirmMark(width: 96),
        ),
      ),
    );
  }
}

// ========================================================================
// EDITORIAL BACKGROUND
// ========================================================================

class _EditorialBackground extends StatelessWidget {
  const _EditorialBackground();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _EditorialBackgroundPainter()),
    );
  }
}

class _EditorialBackgroundPainter extends CustomPainter {
  const _EditorialBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    // Warm paper base.
    canvas.drawRect(bounds, Paint()..color = const Color(0xFFF7F5F2));

    // Extremely subtle warm tonal area.
    final Paint softLight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 0.9,
        colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
      ).createShader(bounds);

    canvas.drawRect(bounds, softLight);

    // Very subtle lower paper depth.
    final Paint lowerTone = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00E9E3DA), Color(0x28D9D0C3)],
      ).createShader(bounds);

    canvas.drawRect(bounds, lowerTone);
  }

  @override
  bool shouldRepaint(covariant _EditorialBackgroundPainter oldDelegate) {
    return false;
  }
}

// ========================================================================
// GOLD LOADING LINE
// ========================================================================

class _GoldLoadingLine extends StatelessWidget {
  const _GoldLoadingLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 2,
      child: CustomPaint(painter: _GoldLoadingPainter(progress: progress)),
    );
  }
}

class _GoldLoadingPainter extends CustomPainter {
  const _GoldLoadingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint trackPaint = Paint()..color = const Color(0xFFE1DBD2);

    final double centerY = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - 0.5, size.width, 1),
        const Radius.circular(1),
      ),
      trackPaint,
    );

    const double segmentWidth = 42;

    final double start = (size.width + segmentWidth) * progress - segmentWidth;

    final Rect segmentRect = Rect.fromLTWH(
      start,
      centerY - 0.7,
      segmentWidth,
      1.4,
    );

    final Paint segmentPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00CCA046), Color(0xFFCCA046), Color(0x00CCA046)],
      ).createShader(segmentRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(segmentRect, const Radius.circular(1)),
      segmentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
