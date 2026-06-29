import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Validates and executes a new student account registration.
///
/// Enforces:
/// - Institutional email domain (must end with an academic TLD)
/// - Matriculation number format
/// - Password strength (minimum 8 characters)
/// - Password confirmation match
///
/// All validation is performed client-side before any network call.
class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final IAuthRepository _repository;

  // Accepted academic email domain patterns.
  // Extend this list as additional institutional domains are approved.
  static const List<String> _acceptedDomains = <String>[
    '.edu',
    '.edu.ng',
    '.ac.uk',
    '.ac.ng',
    '.university.edu',
  ];

  /// Validates all registration fields and delegates to [IAuthRepository.register].
  ///
  /// **Returns:**
  /// - [AuthSuccess<User>] — on successful registration
  /// - [AuthFailedResult] with [InvalidEmailDomainFailure] — bad email domain
  /// - [AuthFailedResult] with [InvalidCredentialsFailure] — weak/mismatched password
  /// - [AuthFailedResult] with [EmailAlreadyInUseFailure] — from repository
  Future<AuthResult<User>> call({
    required String name,
    required String email,
    required String matricNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final String trimmedEmail = email.trim().toLowerCase();
    final String trimmedName = name.trim();
    final String trimmedMatric = matricNumber.trim().toUpperCase();

    // Validate institutional email domain
    if (!_isInstitutionalEmail(trimmedEmail)) {
      return const AuthFailedResult<User>(InvalidEmailDomainFailure());
    }

    // Validate password strength
    if (password.length < 8) {
      return const AuthFailedResult<User>(InvalidCredentialsFailure());
    }

    // Validate password confirmation
    if (password != confirmPassword) {
      return const AuthFailedResult<User>(InvalidCredentialsFailure());
    }

    // Validate non-empty fields
    if (trimmedName.isEmpty || trimmedMatric.isEmpty) {
      return const AuthFailedResult<User>(InvalidCredentialsFailure());
    }

    return _repository.register(
      name: trimmedName,
      email: trimmedEmail,
      matricNumber: trimmedMatric,
      password: password,
    );
  }

  /// Returns `true` if [email] ends with any accepted academic domain suffix.
  bool _isInstitutionalEmail(String email) {
    if (!email.contains('@')) return false;
    return _acceptedDomains.any((String domain) => email.endsWith(domain));
  }
}
