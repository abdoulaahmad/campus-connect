import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Restores a previously authenticated user session on app start.
///
/// Called automatically by [AuthNotifier.build()] via a microtask immediately
/// after the provider initialises. This prevents users from needing to log in
/// on every app launch when their Firebase session is still valid.
///
/// **Flow:**
/// ```
/// App starts
///   → AuthNotifier initialises with AuthLoading
///   → RestoreSessionUseCase.call() runs (microtask)
///   → IAuthRepository.getCurrentUser() checks Firebase/mock state
///   → Returns User? (null if no valid session)
///   → AuthNotifier transitions to AuthAuthenticated or AuthUnauthenticated
///   → RouterNotifier fires refreshListenable
///   → GoRouter redirect routes to correct destination
/// ```
///
/// **Returns:**
/// - [AuthSuccess<User>] — valid session found, user hydrated
/// - [AuthFailedResult] with [NoSessionFailure] — no active session
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final IAuthRepository _repository;

  /// Checks for an active session and returns the current [User] if found.
  Future<AuthResult<User>> call() async {
    final User? user = await _repository.getCurrentUser();

    if (user == null) {
      return const AuthFailedResult<User>(NoSessionFailure());
    }

    return AuthSuccess<User>(user);
  }
}
