import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_theme.dart';
import '../../../core/router/app_router.dart';

/// GoRouter error screen — rendered for unknown routes and navigation failures.
///
/// Displayed when:
/// - A route path does not match any registered route in [appRouter]
/// - GoRouter encounters an internal navigation error
///
/// Provides a branded error view with a "Go Home" recovery action.
/// Resolves MR-005 (missing error screen specification).
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({this.error, super.key});

  /// Optional error message from GoRouter's [GoRouterState.error].
  /// Displayed in a collapsible detail section for debugging.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Navigation Error'),
        backgroundColor: AppTheme.surface,
        leading: BackButton(
          onPressed: () {
            // Attempt to go back; if no history, go to splash.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.splash);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),

              // ── Error Icon ─────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.error.withAlpha(20),
                    border: Border.all(
                      color: AppTheme.error.withAlpha(80),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    size: 48,
                    color: AppTheme.error,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceXL),

              // ── Error Title ────────────────────────────────────────────────
              Text(
                'Page Not Found',
                textAlign: TextAlign.center,
                style: text.headlineLarge,
              ),

              const SizedBox(height: AppTheme.spaceSM),

              Text(
                'The route you navigated to does not exist\nor is not accessible.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),

              // ── Error Detail (debug) ───────────────────────────────────────
              if (error != null) ...<Widget>[
                const SizedBox(height: AppTheme.spaceLG),
                _ErrorDetail(error: error!),
              ],

              const Spacer(),

              // ── Recovery Action ────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.splash),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Return to Home'),
              ),

              const SizedBox(height: AppTheme.spaceMD),

              OutlinedButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.splash);
                  }
                },
                icon: const Icon(Icons.arrow_back_outlined),
                label: const Text('Go Back'),
              ),

              const SizedBox(height: AppTheme.spaceLG),

              // ── Campus Code Footer ─────────────────────────────────────────
              Text(
                'CampusConnect AUS · CAM-AUS-11',
                textAlign: TextAlign.center,
                style: text.labelSmall?.copyWith(
                  color: AppTheme.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error Detail Widget ───────────────────────────────────────────────────

/// Collapsible error detail section for debugging navigation failures.
class _ErrorDetail extends StatefulWidget {
  const _ErrorDetail({required this.error});

  final String error;

  @override
  State<_ErrorDetail> createState() => _ErrorDetailState();
}

class _ErrorDetailState extends State<_ErrorDetail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Technical details',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textDisabled,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: AppTheme.textDisabled,
              ),
            ],
          ),
        ),
        if (_expanded) ...<Widget>[
          const SizedBox(height: AppTheme.spaceSM),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha(15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.error.withAlpha(60)),
            ),
            child: Text(
              widget.error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.error,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
