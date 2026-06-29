import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Authenticates the user using device biometric hardware.
///
/// This use case is only available after the user has previously completed
/// a full email+password [LoginUseCase] and opted in to biometric login.
/// The preference is persisted via [SecureStorageService].
///
/// **Flow:**
/// 1. Repository checks device biometric availability
/// 2. OS-level biometric prompt is shown to user
/// 3. On success: stored `last_logged_in_user_id` is used to hydrate User
/// 4. On failure: typed [AuthFailure] is returned
///
/// **Returns:**
/// - [AuthSuccess<User>] — biometric verified, user hydrated
/// - [AuthFailedResult] with [BiometricUnavailableFailure] — not enrolled/supported
/// - [AuthFailedResult] with [BiometricCancelledFailure] — user dismissed prompt
/// - [AuthFailedResult] with [UserNotFoundFailure] — no stored user ID found
class BiometricAuthUseCase {
  const BiometricAuthUseCase(this._repository);

  final IAuthRepository _repository;

  /// Triggers biometric authentication flow.
  Future<AuthResult<User>> call() => _repository.biometricLogin();
}
