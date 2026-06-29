import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/biometric_auth_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import 'auth_state.dart';

// ── AuthNotifier ──────────────────────────────────────────────────────────

/// Riverpod [Notifier] that manages the authentication lifecycle.
///
/// **Initial state:** [AuthLoading] — a microtask immediately triggers
/// session restore to check for an existing Firebase session.
///
/// **State machine:**
/// - [AuthLoading] → on boot, before session check completes
/// - [AuthAuthenticated] → valid session or successful login
/// - [AuthUnauthenticated] → no session, after logout, or after error recovery
/// - [AuthError] → unexpected failure (shows on splash before recovering)
///
/// All auth operations are delegated to use cases in the domain layer.
/// This class contains zero business logic — only state transitions.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Fire-and-forget session restore via microtask.
    // Microtask ensures build() returns synchronously before async work runs.
    Future<void>(() => _restoreSession());
    return const AuthLoading();
  }

  // ── Session Restore ───────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    print('DEBUG: _restoreSession starting');
    final result = await RestoreSessionUseCase(
      ref.read(authRepositoryProvider),
    ).call().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        print('DEBUG: _restoreSession timed out after 8s');
        return const AuthFailedResult<User>(NoSessionFailure());
      },
    );
    print('DEBUG: restore session result: $result');

    switch (result) {
      case AuthSuccess(:final value):
        state = AuthAuthenticated(value);
      case AuthFailedResult(:final failure):
        // NoSessionFailure is the normal case — not an error.
        if (failure is NoSessionFailure) {
          state = const AuthUnauthenticated();
        } else {
          state = AuthError(failure.runtimeType.toString());
        }
    }
    print('DEBUG: AuthNotifier state updated to: $state');
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  /// Authenticates with email and password.
  ///
  /// Returns `null` on success (state transitions to [AuthAuthenticated]).
  /// Returns a human-readable error message string on failure.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();

    final result = await LoginUseCase(
      ref.read(authRepositoryProvider),
    ).call(email: email, password: password);

    switch (result) {
      case AuthSuccess(:final value):
        state = AuthAuthenticated(value);
        return null;
      case AuthFailedResult(:final failure):
        state = const AuthUnauthenticated();
        return _failureMessage(failure);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  /// Creates a new student account.
  ///
  /// Returns `null` on success (state transitions to [AuthAuthenticated]).
  /// Returns a human-readable error message string on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String matricNumber,
    required String password,
    required String confirmPassword,
  }) async {
    state = const AuthLoading();

    final result = await RegisterUseCase(
      ref.read(authRepositoryProvider),
    ).call(
      name: name,
      email: email,
      matricNumber: matricNumber,
      password: password,
      confirmPassword: confirmPassword,
    );

    switch (result) {
      case AuthSuccess(:final value):
        state = AuthAuthenticated(value);
        return null;
      case AuthFailedResult(:final failure):
        state = const AuthUnauthenticated();
        return _failureMessage(failure);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  /// Signs out and clears the session.
  ///
  /// State transitions to [AuthUnauthenticated] which triggers GoRouter
  /// to redirect to [AppRoutes.login].
  Future<void> logout() async {
    await LogoutUseCase(ref.read(authRepositoryProvider)).call();
    state = const AuthUnauthenticated();
  }

  // ── Biometric Login ───────────────────────────────────────────────────────

  /// Attempts biometric authentication.
  ///
  /// Returns `null` on success. Returns error message on failure.
  Future<String?> biometricLogin() async {
    state = const AuthLoading();

    final result = await BiometricAuthUseCase(
      ref.read(authRepositoryProvider),
    ).call();

    switch (result) {
      case AuthSuccess(:final value):
        state = AuthAuthenticated(value);
        return null;
      case AuthFailedResult(:final failure):
        state = const AuthUnauthenticated();
        return _failureMessage(failure);
    }
  }

  // ── Error Recovery ────────────────────────────────────────────────────────

  /// Resets an [AuthError] state back to [AuthUnauthenticated].
  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }

  // ── Failure → Message ─────────────────────────────────────────────────────

  String _failureMessage(AuthFailure failure) {
    return switch (failure) {
      InvalidCredentialsFailure() => 'Invalid email or password.',
      UserNotFoundFailure() => 'No account found for this email.',
      EmailAlreadyInUseFailure() => 'An account already exists with this email.',
      BiometricUnavailableFailure() =>
        'Biometric authentication is not available on this device.',
      BiometricCancelledFailure() => 'Biometric authentication was cancelled.',
      NoSessionFailure() => 'No active session found.',
      NetworkFailure() => 'Network error. Please check your connection.',
      ServerFailure(:final message) => message,
      InvalidEmailDomainFailure() =>
        'Please use your institutional email address (e.g. student@university.edu).',
    };
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

/// Global [AuthNotifier] provider.
///
/// Watched by [RouterNotifier] to trigger navigation on auth state changes.
/// Consumed by login/register screens to trigger auth operations.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
