import '../repositories/i_auth_repository.dart';

/// Signs out the current user and clears all local session data.
///
/// Resolves MR-003 (logout mechanism).
///
/// The repository implementation is responsible for:
/// 1. Calling `FirebaseAuth.signOut()` (prod) or clearing in-memory state (dev/test)
/// 2. Calling `SecureStorageService.clearSession()` to remove stored identifiers
///
/// This use case does not return a failure type — logout is always treated
/// as successful from the user's perspective. Any internal errors are
/// logged but do not block the user from reaching the login screen.
class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final IAuthRepository _repository;

  /// Executes the logout sequence.
  ///
  /// After this call, [IAuthRepository.getCurrentUser] will return `null`
  /// and [AuthNotifier] will transition to [AuthUnauthenticated].
  Future<void> call() => _repository.logout();
}
