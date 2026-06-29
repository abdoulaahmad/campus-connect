import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/error/presentation/error_screen.dart';
import '../../features/messaging/domain/entities/chat.dart';
import '../../features/messaging/presentation/screens/chat_room_screen.dart';
import '../../features/messaging/presentation/screens/chats_screen.dart';
import '../../features/shell/presentation/admin_shell.dart';
import '../../features/shell/presentation/student_shell.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/marketplace/presentation/screens/create_listing_screen.dart';
import '../../features/marketplace/presentation/screens/listing_detail_screen.dart';
import '../../features/marketplace/presentation/screens/qr_scanner_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/sos/presentation/screens/sos_screen.dart';
import '../../features/schedule/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

// ── Route Path Constants ──────────────────────────────────────────────────

/// Named route path constants for CampusConnect AUS.
///
/// All navigation calls use these constants. Never use raw string literals
/// for route paths outside of this file.
abstract final class AppRoutes {
  // Root
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Student shell routes
  static const String home = '/home';
  static const String chats = '/chats';
  static const String chatRoom = '/chats/room';
  static const String map = '/map';
  static const String marketplace = '/marketplace';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String sos = '/sos';

  // Admin shell routes
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminEvents = '/admin/events';
  static const String adminAnnouncements = '/admin/announcements';
  static const String adminAlerts = '/admin/alerts';
}

// ── Router Notifier ───────────────────────────────────────────────────────

/// [ChangeNotifier] bridge between Riverpod [AuthNotifier] and GoRouter.
///
/// This solves the Riverpod + GoRouter integration problem described in the
/// Sprint 2 review. Using `refreshListenable` instead of reading async
/// notifiers inside `redirect()` prevents redirect loops.
///
/// **How it works:**
/// 1. [RouterNotifier] listens to [authProvider] via `ref.listen`
/// 2. On any [AuthState] change, it calls `notifyListeners()`
/// 3. GoRouter's `refreshListenable` detects the notification
/// 4. GoRouter calls `redirect()` to re-evaluate the current route
/// 5. [redirect] reads the CURRENT auth state via `ref.read` (not watch)
///
/// **No redirect loops:** Because `refreshListenable` and `redirect` are
/// decoupled, the redirect function only runs when auth state actually changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    print('DEBUG: RouterNotifier constructor started');
    // Listen to auth state changes and notify GoRouter to re-evaluate.
    _ref.listen<AuthState>(authProvider, (prev, next) {
      print('DEBUG: RouterNotifier listener triggered: $prev -> $next');
      notifyListeners();
    });
  }

  final Ref _ref;

  /// GoRouter redirect function.
  ///
  /// Called every time the router evaluates a navigation event or
  /// [notifyListeners] fires via auth state changes.
  ///
  /// Returns a redirect path string, or `null` to allow the navigation.
  String? redirect(BuildContext context, GoRouterState state) {
    final AuthState authState = _ref.read(authProvider);
    final String location = state.uri.path;
    print('DEBUG: RouterNotifier.redirect called: authState=$authState, location=$location');

    final String? result = switch (authState) {
      // While loading: keep user on splash OR auth screens (so login/register
      // spinners are visible and errors can be shown). Only redirect other
      // routes (e.g. deep links during boot) to splash.
      AuthLoading() => (location == AppRoutes.splash ||
              location == AppRoutes.login ||
              location == AppRoutes.register)
          ? null
          : AppRoutes.splash,

      // Authenticated: route to correct shell, enforce role boundaries.
      AuthAuthenticated(:final user) => _authenticatedRedirect(location, user),

      // Unauthenticated or error: protect all non-auth routes.
      AuthUnauthenticated() || AuthError() => _unauthenticatedRedirect(location),
    };
    print('DEBUG: RouterNotifier.redirect returning: $result');
    return result;
  }

  // ── Redirect Helpers ──────────────────────────────────────────────────────

  String? _authenticatedRedirect(String location, User user) {
    // Redirect away from auth/splash screens once signed in.
    if (_isAuthRoute(location)) {
      return user.isAdmin ? AppRoutes.adminDashboard : AppRoutes.home;
    }

    // Student trying to access admin routes → go home.
    if (!user.isAdmin && location.startsWith('/admin')) {
      return AppRoutes.home;
    }

    // Admin trying to access student routes (except global SOS) → go to dashboard.
    if (user.isAdmin && !location.startsWith('/admin') && !_isGlobalRoute(location)) {
      return AppRoutes.adminDashboard;
    }

    return null; // Allow navigation.
  }

  String? _unauthenticatedRedirect(String location) {
    if (location == AppRoutes.login || location == AppRoutes.register) return null;
    return AppRoutes.login;
  }

  bool _isAuthRoute(String location) =>
      location == AppRoutes.splash ||
      location == AppRoutes.login ||
      location == AppRoutes.register;

  /// Routes accessible regardless of role (e.g. SOS emergency screen).
  bool _isGlobalRoute(String location) => location == AppRoutes.sos;
}

// ── Router Provider ───────────────────────────────────────────────────────

/// Riverpod provider exposing the [RouterNotifier].
///
/// Declared as [ChangeNotifierProvider] so that Riverpod manages the lifecycle
/// and the notifier is properly disposed on provider teardown.
final routerNotifierProvider = ChangeNotifierProvider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Riverpod provider exposing the configured [GoRouter] instance.
///
/// Uses `ref.read` (not `ref.watch`) so that the GoRouter is created exactly
/// once and cached for the lifetime of the [ProviderScope]. The notifier
/// handles refresh triggering — GoRouter does not need to be recreated.
final routerProvider = Provider<GoRouter>((ref) {
  final RouterNotifier notifier = ref.read(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    errorBuilder: (BuildContext context, GoRouterState state) {
      return ErrorScreen(error: state.error?.toString());
    },
    routes: <RouteBase>[
      // ── Splash ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),

      // ── Auth Routes ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen();
        },
      ),

      // ── Student Shell ───────────────────────────────────────────────────
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return StudentShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.chats,
            name: 'chats',
            builder: (BuildContext context, GoRouterState state) => const ChatsScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'room',
                name: 'chatRoom',
                builder: (BuildContext context, GoRouterState state) {
                  final chat = state.extra as Chat;
                  return ChatRoomScreen(chat: chat);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.map,
            name: 'map',
            builder: (BuildContext context, GoRouterState state) => const MapScreen(),
          ),
          GoRoute(
            path: AppRoutes.marketplace,
            name: 'marketplace',
            builder: (BuildContext context, GoRouterState state) => const MarketplaceScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'create',
                name: 'createListing',
                builder: (BuildContext context, GoRouterState state) => const CreateListingScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'listingDetail',
                builder: (BuildContext context, GoRouterState state) {
                  final id = state.pathParameters['id'] ?? '';
                  return ListingDetailScreen(listingId: id);
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'scan',
                    name: 'qrScanner',
                    builder: (BuildContext context, GoRouterState state) {
                      final id = state.pathParameters['id'] ?? '';
                      return QrScannerScreen(listingId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (BuildContext context, GoRouterState state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (BuildContext context, GoRouterState state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.sos,
            name: 'sos',
            builder: (BuildContext context, GoRouterState state) => const SosScreen(),
          ),
        ],
      ),

      // ── Admin Shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AdminShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.adminDashboard,
            name: 'adminDashboard',
            builder: (BuildContext context, GoRouterState state) => const AdminDashboardScreen(initialTab: 0),
          ),
          GoRoute(
            path: AppRoutes.adminUsers,
            name: 'adminUsers',
            builder: (BuildContext context, GoRouterState state) => const AdminDashboardScreen(initialTab: 1),
          ),
          GoRoute(
            path: AppRoutes.adminEvents,
            name: 'adminEvents',
            builder: (BuildContext context, GoRouterState state) => const AdminDashboardScreen(initialTab: 2),
          ),
          GoRoute(
            path: AppRoutes.adminAnnouncements,
            name: 'adminAnnouncements',
            builder: (BuildContext context, GoRouterState state) => const AdminDashboardScreen(initialTab: 0),
          ),
          GoRoute(
            path: AppRoutes.adminAlerts,
            name: 'adminAlerts',
            builder: (BuildContext context, GoRouterState state) => const AdminDashboardScreen(initialTab: 3),
          ),
        ],
      ),
    ],
  );
});


