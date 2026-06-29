import '../../domain/entities/user.dart';

/// Sealed state hierarchy for the authentication feature.
///
/// Used by [AuthNotifier] and consumed by the GoRouter [RouterNotifier]
/// via `refreshListenable` to trigger navigation without redirect loops.
///
/// **State transitions:**
/// ```
/// AuthLoading (initial)
///   → AuthAuthenticated (session found or login succeeded)
///   → AuthUnauthenticated (no session or logout)
///   → AuthError (unexpected failure during session restore)
/// ```
sealed class AuthState {
  const AuthState();
}

/// The auth check is in progress.
///
/// Shown during initial session restore on app start.
/// The splash screen remains visible until this state resolves.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A valid user session is active.
///
/// The [user] is the fully hydrated [User] entity.
/// GoRouter routes this to [AppRoutes.home] (student) or
/// [AppRoutes.adminDashboard] (admin).
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;
}

/// No active session — user must log in.
///
/// GoRouter routes this to [AppRoutes.login] for all protected routes.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An unexpected error occurred during session restore or authentication.
///
/// [message] is a human-readable description. GoRouter treats this
/// identically to [AuthUnauthenticated] and routes to login.
final class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
