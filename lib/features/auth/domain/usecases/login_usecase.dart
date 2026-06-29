import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Validates and executes an email + password login.
///
/// Client-side validation is performed before any repository call,
/// ensuring network traffic is never generated for obviously invalid input.
///
/// **Returns:**
/// - [AuthSuccess<User>] — on successful authentication
/// - [AuthFailedResult] — with a typed [AuthFailure] on any failure
class LoginUseCase {
  const LoginUseCase(this._repository);

  final IAuthRepository _repository;

  /// Validates [email] and [password], then delegates to [IAuthRepository.login].
  ///
  /// **Validation:**
  /// - Email must not be empty and must contain `@`
  /// - Password must be at least 6 characters
  ///
  /// Returns an [AuthFailedResult<User>] with [InvalidCredentialsFailure]
  /// immediately if client-side validation fails (no network call made).
  Future<AuthResult<User>> call({
    required String email,
    required String password,
  }) async {
    // Client-side guard: trim inputs before any validation
    final String trimmedEmail = email.trim().toLowerCase();
    final String trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty ||
        !trimmedEmail.contains('@') ||
        trimmedPassword.length < 6) {
      return const AuthFailedResult<User>(InvalidCredentialsFailure());
    }

    return _repository.login(
      email: trimmedEmail,
      password: trimmedPassword,
    );
  }
}
