import '../entities/user.dart';
import '../failures/auth_failure.dart';

/// Abstract authentication repository contract.
///
/// This interface is the only auth-related abstraction the domain and
/// presentation layers depend on. All three concrete implementations
/// (Firebase, Mockoon, Mock) must satisfy this contract exactly.
///
/// **Implementations:**
/// - `FirebaseAuthRepository` — production (ENV=prod)
/// - `MockoonAuthRepository` — Mockoon dev server (ENV=dev)
/// - `MockAuthRepository` — in-memory test fixtures (ENV=test)
///
/// **Error handling:** All methods return [AuthResult] — never throw.
/// Platform exceptions are caught and mapped inside each implementation.
abstract class IAuthRepository {
  const IAuthRepository();

  /// Authenticates a user with email and password.
  ///
  /// Returns [AuthSuccess<User>] on success.
  /// Returns [AuthFailedResult] with one of:
  /// - [InvalidCredentialsFailure] — wrong password
  /// - [UserNotFoundFailure] — no account for this email
  /// - [NetworkFailure] — connectivity issue
  /// - [ServerFailure] — unexpected server error
  Future<AuthResult<User>> login({
    required String email,
    required String password,
  });

  /// Creates a new student account.
  ///
  /// The [email] is validated for institutional domain client-side before
  /// this method is called (see [RegisterUseCase]).
  ///
  /// Returns [AuthSuccess<User>] on success.
  /// Returns [AuthFailedResult] with one of:
  /// - [EmailAlreadyInUseFailure] — account exists
  /// - [NetworkFailure] — connectivity issue
  /// - [ServerFailure] — unexpected error
  Future<AuthResult<User>> register({
    required String name,
    required String email,
    required String matricNumber,
    required String password,
  });

  /// Signs out the current user and clears all local session data.
  ///
  /// This method must call [SecureStorageService.clearSession()] internally
  /// to remove stored user identifiers. Does not throw.
  Future<void> logout();

  /// Returns the currently authenticated [User], or `null` if no session exists.
  ///
  /// Used by [RestoreSessionUseCase] on app start to hydrate [AuthNotifier].
  /// Firebase implementation checks `FirebaseAuth.instance.currentUser`.
  Future<User?> getCurrentUser();

  /// Authenticates using the device biometric hardware (fingerprint / FaceID).
  ///
  /// Requires a previous [login] to have succeeded and
  /// `preferred_biometric_login` to be set in [SecureStorageService].
  ///
  /// Returns [AuthSuccess<User>] on success.
  /// Returns [AuthFailedResult] with one of:
  /// - [BiometricUnavailableFailure] — device doesn't support biometrics
  /// - [BiometricCancelledFailure] — user cancelled the prompt
  /// - [UserNotFoundFailure] — no stored userId for biometric recovery
  Future<AuthResult<User>> biometricLogin();
}
