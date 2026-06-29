/// Typed failure hierarchy for the Authentication feature.
///
/// All auth repository implementations must map their platform-specific
/// errors to one of these sealed failure types. No raw exceptions are
/// propagated beyond the data layer boundary.
///
/// **Usage pattern:**
/// ```dart
/// final result = await loginUseCase(email: e, password: p);
/// switch (result) {
///   case AuthSuccess(:final value): ...
///   case AuthFailedResult(:final failure): switch (failure) { ... }
/// }
/// ```
sealed class AuthFailure {
  const AuthFailure();
}

/// Email or password is incorrect.
final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// No account exists for the given email address.
final class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure();
}

/// An account already exists with the given email address.
final class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure();
}

/// The device does not support biometric authentication,
/// or the user has not enrolled any biometrics.
final class BiometricUnavailableFailure extends AuthFailure {
  const BiometricUnavailableFailure();
}

/// The biometric authentication prompt was dismissed or cancelled
/// by the user without completing authentication.
final class BiometricCancelledFailure extends AuthFailure {
  const BiometricCancelledFailure();
}

/// No previous session was found to restore.
///
/// Returned by [RestoreSessionUseCase] when no user is currently
/// signed in on Firebase or in the mock in-memory store.
final class NoSessionFailure extends AuthFailure {
  const NoSessionFailure();
}

/// A network error prevented the request from completing.
///
/// Covers: no connectivity, DNS failure, connection timeout.
final class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

/// The remote server returned an unexpected or non-2xx response.
final class ServerFailure extends AuthFailure {
  const ServerFailure(this.message);

  /// Human-readable description of the server error.
  final String message;
}

/// The provided email does not belong to an approved institutional domain.
///
/// Validated client-side before any network call is made.
/// Accepted pattern: must contain `@` followed by a domain ending in
/// `.edu`, `.ac.uk`, `.edu.ng`, or similar academic TLDs.
final class InvalidEmailDomainFailure extends AuthFailure {
  const InvalidEmailDomainFailure();
}

// ── Result Type ───────────────────────────────────────────────────────────

/// Discriminated result type for all auth operations.
///
/// Eliminates bare `try/catch` blocks from the presentation layer.
/// Every auth use case returns `AuthResult<T>` and callers pattern-match
/// on the subtypes.
///
/// ```dart
/// switch (result) {
///   case AuthSuccess(:final value): handleSuccess(value);
///   case AuthFailedResult(:final failure): handleFailure(failure);
/// }
/// ```
sealed class AuthResult<T> {
  const AuthResult();
}

/// The auth operation completed successfully. [value] holds the result.
final class AuthSuccess<T> extends AuthResult<T> {
  const AuthSuccess(this.value);

  final T value;
}

/// The auth operation failed. [failure] is a typed [AuthFailure] subtype.
final class AuthFailedResult<T> extends AuthResult<T> {
  const AuthFailedResult(this.failure);

  final AuthFailure failure;
}
