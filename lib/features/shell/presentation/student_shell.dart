import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_theme.dart';
import '../../../core/router/app_router.dart';

/// Student navigation shell — persistent layout wrapper for all student routes.
///
/// Provides:
/// - A [BottomNavigationBar] with 5 primary tabs
/// - A persistent floating SOS action button (bottom-right, always visible)
///
/// Uses GoRouter's [ShellRoute] pattern — the [child] widget is the content
/// of the currently active route. The nav bar and SOS FAB persist across
/// all tab switches without re-rendering.
///
/// **Tabs (in order):**
/// 1. Home — `/home`
/// 2. Chats — `/chats`
/// 3. Map — `/map`
/// 4. Marketplace — `/marketplace`
/// 5. Profile — `/profile`
///
/// **SOS FAB:** Routes to `/sos`. Rendered above the nav bar in a [Stack]
/// so it floats permanently regardless of active tab.
class StudentShell extends StatelessWidget {
  const StudentShell({required this.child, super.key});

  /// The active route's screen content, injected by GoRouter's [ShellRoute].
  final Widget child;

  // ── Tab Definitions ───────────────────────────────────────────────────────

  static const List<_TabDefinition> _tabs = <_TabDefinition>[
    _TabDefinition(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      route: AppRoutes.home,
    ),
    _TabDefinition(
      label: 'Chats',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.chats,
    ),
    _TabDefinition(
      label: 'Map',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      route: AppRoutes.map,
    ),
    _TabDefinition(
      label: 'Market',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
      route: AppRoutes.marketplace,
    ),
    _TabDefinition(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      route: AppRoutes.profile,
    ),
  ];

  // ── Tab Index Resolution ──────────────────────────────────────────────────

  /// Determines the active tab index from the current GoRouter location.
  int _activeIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/chats')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/marketplace')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _activeIndex(context);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // ── Main Content ─────────────────────────────────────────────────
          child,

          // ── SOS FAB Overlay ──────────────────────────────────────────────
          // Positioned above bottom nav bar, always visible across all tabs.
          Positioned(
            right: AppTheme.spaceMD,
            bottom: kBottomNavigationBarHeight + AppTheme.spaceMD,
            child: _SosFab(),
          ),
        ],
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (int index) => context.go(_tabs[index].route),
        items: _tabs
            .map(
              (_TabDefinition tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                activeIcon: Icon(tab.activeIcon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── SOS Floating Action Button ────────────────────────────────────────────

/// Persistent emergency SOS floating action button.
///
/// Displayed in the bottom-right corner of every student screen,
/// above the [BottomNavigationBar]. Routes to [AppRoutes.sos] on tap.
///
/// Styled with a pulsing animation to draw attention as a safety tool.
/// The animation is always active to reinforce its emergency purpose.
class _SosFab extends StatefulWidget {
  @override
  State<_SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<_SosFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: FloatingActionButton(
        heroTag: 'sos_fab',
        tooltip: 'Emergency SOS',
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        elevation: 8,
        onPressed: () => context.push(AppRoutes.sos),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.warning_rounded, size: 20),
            Text(
              'SOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Definition Model ──────────────────────────────────────────────────

/// Immutable definition for a bottom navigation tab.
class _TabDefinition {
  const _TabDefinition({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
