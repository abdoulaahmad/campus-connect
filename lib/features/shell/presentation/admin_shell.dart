import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_theme.dart';
import '../../../core/router/app_router.dart';

/// Admin navigation shell — persistent layout wrapper for all admin routes.
///
/// Provides a [NavigationDrawer] sidebar with 4 administrative sections:
/// 1. Dashboard — `/admin`
/// 2. User Management — `/admin/users`
/// 3. Event Management — `/admin/events`
/// 4. Announcements — `/admin/announcements`
/// 5. Emergency Alerts — `/admin/alerts`
///
/// Uses GoRouter's [ShellRoute] pattern. The [child] widget is the content
/// of the currently active admin route. The drawer is accessible via the
/// AppBar hamburger menu on all admin screens.
///
/// **Role isolation:** This shell is never rendered for student users.
/// The GoRouter role guard in [app_router.dart] enforces this boundary.
class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, super.key});

  /// The active admin route's screen content, injected by [ShellRoute].
  final Widget child;

  // ── Drawer Item Definitions ────────────────────────────────────────────────

  static const List<_DrawerItem> _drawerItems = <_DrawerItem>[
    _DrawerItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      route: AppRoutes.adminDashboard,
    ),
    _DrawerItem(
      label: 'User Management',
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
      route: AppRoutes.adminUsers,
    ),
    _DrawerItem(
      label: 'Event Management',
      icon: Icons.event_outlined,
      activeIcon: Icons.event_rounded,
      route: AppRoutes.adminEvents,
    ),
    _DrawerItem(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      route: AppRoutes.adminAnnouncements,
    ),
    _DrawerItem(
      label: 'Emergency Alerts',
      icon: Icons.emergency_outlined,
      activeIcon: Icons.emergency_rounded,
      route: AppRoutes.adminAlerts,
    ),
  ];

  // ── Active Route Resolution ────────────────────────────────────────────────

  /// Returns the route path of the currently active admin section.
  String _activeRoute(BuildContext context) {
    return GoRouterState.of(context).uri.path;
  }

  @override
  Widget build(BuildContext context) {
    final String currentRoute = _activeRoute(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_routeTitle(currentRoute)),
        leading: Builder(
          builder: (BuildContext ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open navigation menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: const <Widget>[
          // Admin identity badge
          Padding(
            padding: EdgeInsets.only(right: AppTheme.spaceMD),
            child: Chip(
              avatar: Icon(
                Icons.admin_panel_settings,
                size: 14,
                color: AppTheme.onPrimary,
              ),
              label: Text(
                'Admin',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onPrimary,
                ),
              ),
              backgroundColor: AppTheme.primaryLight,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),

      // ── Navigation Drawer ──────────────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: AppTheme.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Drawer header
              _buildDrawerHeader(context),

              const Divider(height: 1),

              const SizedBox(height: AppTheme.spaceSM),

              // Navigation items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSM,
                  ),
                  itemCount: _drawerItems.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _DrawerItem item = _drawerItems[index];
                    final bool isActive = currentRoute == item.route ||
                        (item.route == AppRoutes.adminDashboard &&
                            currentRoute == '/admin');
                    return _DrawerTile(
                      item: item,
                      isActive: isActive,
                      onTap: () {
                        Navigator.of(context).pop(); // close drawer
                        context.go(item.route);
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Footer — campus code
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Text(
                  'CAM-AUS-11 · Group 11',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textDisabled,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Screen Content ────────────────────────────────────────────────────
      body: child,
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      color: AppTheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.admin_panel_settings_rounded,
            size: 40,
            color: AppTheme.onPrimary,
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'CampusConnect AUS',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            'Administration Panel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onPrimary.withAlpha(180),
                ),
          ),
        ],
      ),
    );
  }

  /// Returns a human-readable title for the current admin route.
  String _routeTitle(String route) {
    switch (route) {
      case AppRoutes.adminUsers:
        return 'User Management';
      case AppRoutes.adminEvents:
        return 'Event Management';
      case AppRoutes.adminAnnouncements:
        return 'Announcements';
      case AppRoutes.adminAlerts:
        return 'Emergency Alerts';
      default:
        return 'Admin Dashboard';
    }
  }
}

// ── Drawer Tile ───────────────────────────────────────────────────────────

/// A single item tile in the admin [NavigationDrawer].
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _DrawerItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceXS),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withAlpha(40)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: isActive
            ? Border.all(color: AppTheme.primary.withAlpha(80))
            : null,
      ),
      child: ListTile(
        leading: Icon(
          isActive ? item.activeIcon : item.icon,
          color: isActive ? AppTheme.primary : AppTheme.textSecondary,
          size: 22,
        ),
        title: Text(
          item.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isActive ? AppTheme.onPrimary : AppTheme.textSecondary,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        dense: true,
      ),
    );
  }
}

// ── Drawer Item Model ─────────────────────────────────────────────────────

/// Immutable definition for an admin navigation drawer item.
class _DrawerItem {
  const _DrawerItem({
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
