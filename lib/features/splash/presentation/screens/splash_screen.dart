import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_theme.dart';

/// Splash screen — the application security and configuration gate.
///
/// **Responsibilities:**
/// 1. Display the CampusConnect AUS brand logo with glow animation
/// 2. Confirm [AppConfig] was validated successfully (CAM-AUS-11 check)
/// 3. Show campus code and version for assignment identification
///
/// Navigation is handled externally by [RouterNotifier] which watches
/// [AuthNotifier]. Once [AuthState] transitions from [AuthLoading],
/// GoRouter automatically redirects to the correct destination.
///
/// If config validation fails, a boot-halt error state is shown — no retry.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ─────────────────────────────────────────────────

  late final AnimationController _glowController;
  late final AnimationController _fadeController;

  late final Animation<double> _glowAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _configValid = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runBootSequence();
  }

  void _initAnimations() {
    // Glow pulse — repeating breathe effect on logo ring
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Fade + scale — entrance animation for logo and text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  Future<void> _runBootSequence() async {
    // Brief pause for animation entrance before config check.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    try {
      // AppConfig was validated in main() before runApp().
      // We confirm success by reading the values here.
      final String code = AppConfig.campusCode;
      final String path = AppConfig.apiBasePath;

      if (code == 'CAM-AUS-11' && path == '/api/v2/aus/') {
        if (mounted) setState(() => _configValid = true);
      } else {
        if (mounted) {
          setState(() {
            _validationError =
                'Config mismatch: campus_code=$code, api_base_path=$path';
          });
        }
        return;
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _validationError = e.toString());
      }
      return;
    }

    // Sprint 2: Navigation is handled by RouterNotifier + GoRouter refreshListenable.
    // AuthNotifier.build() fires a microtask to restore the session.
    // Once AuthState transitions from AuthLoading, the router redirects
    // automatically to /login (unauthenticated) or /home|/admin (authenticated).
    // No manual context.go() call needed here.
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _validationError != null
            ? _buildErrorState()
            : _buildSplashContent(),
      ),
    );
  }

  Widget _buildSplashContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(flex: 2),

              // ── Logo Ring ───────────────────────────────────────────────
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (BuildContext context, Widget? child) {
                  return Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.background,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.primary
                              .withAlpha((_glowAnimation.value * 180).toInt()),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: AppTheme.secondary
                              .withAlpha((_glowAnimation.value * 80).toInt()),
                          blurRadius: 60,
                          spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.primary.withAlpha(
                          (_glowAnimation.value * 200).toInt(),
                        ),
                        width: 2.5,
                      ),
                    ),
                    child: child,
                  );
                },
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: 64,
                    color: AppTheme.onPrimary,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceXL),

              // ── App Name ─────────────────────────────────────────────────
              Text(
                'CampusConnect',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                'AUS',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
              ),

              const SizedBox(height: AppTheme.spaceMD),

              // ── Subtitle ─────────────────────────────────────────────────
              Text(
                'Unified Intelligent Mobile Campus Platform',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),

              const Spacer(flex: 2),

              // ── Validation Badge ──────────────────────────────────────────
              _buildValidationBadge(),

              const SizedBox(height: AppTheme.spaceLG),

              // ── Loading Indicator ─────────────────────────────────────────
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.inputFill,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.secondary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              const SizedBox(height: AppTheme.spaceSM),

              Text(
                _configValid ? 'Configuration verified ✓' : 'Validating...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _configValid
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
              ),

              const SizedBox(height: AppTheme.spaceXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primary.withAlpha(80),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.verified_outlined,
                size: 14,
                color: AppTheme.secondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'CAM-AUS-11 • Group 11',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.secondary,
                        letterSpacing: 0.8,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'v${_configValid ? AppConfig.version : "—"} · /api/v2/aus/',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textDisabled,
                ),
          ),
        ],
      ),
    );
  }

  /// Boot-halt error state shown when config validation fails.
  ///
  /// Displays the failure reason. No retry is offered — a config mismatch
  /// is a hard stop requiring a code fix.
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            size: 72,
            color: AppTheme.error,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            'Boot Halted',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.error,
                ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'Configuration validation failed.\nApp cannot start with invalid parameters.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: AppTheme.spaceLG),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha(20),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.error.withAlpha(80)),
            ),
            child: Text(
              _validationError ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.error,
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
