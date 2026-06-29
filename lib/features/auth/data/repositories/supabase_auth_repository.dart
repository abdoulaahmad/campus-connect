import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Production [IAuthRepository] using Supabase Auth + Postgres.
///
/// Auth is handled by `supabase_flutter`. After login/register the user
/// profile is written to the `users` table so role and matric_number are
/// persisted alongside the Supabase auth record.
///
/// Session persistence is handled automatically by the Supabase SDK.
class SupabaseAuthRepository implements IAuthRepository {
  SupabaseAuthRepository({
    required SecureStorageService storage,
    sb.SupabaseClient? client,
    LocalAuthentication? localAuth,
  })  : _client = client ?? sb.Supabase.instance.client,
        _storage = storage,
        _localAuth = localAuth ?? LocalAuthentication();

  final sb.SupabaseClient _client;
  final SecureStorageService _storage;
  final LocalAuthentication _localAuth;

  @override
  Future<AuthResult<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[Auth] login() called for $email');
      final sb.AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final sb.User? sbUser = response.user;
      if (sbUser == null) {
        debugPrint('[Auth] login() - no user in response');
        return const AuthFailedResult<User>(ServerFailure('No user returned'));
      }

      debugPrint('[Auth] login() - success, uid=${sbUser.id}');
      final User user = await _fetchOrBuildUser(sbUser);
      await _storage.saveLastUserId(user.id);
      return AuthSuccess<User>(user);
    } on sb.AuthException catch (e) {
      debugPrint('[Auth] login() - AuthException: ${e.message} (status: ${e.statusCode})');
      return AuthFailedResult<User>(_mapSupabaseError(e));
    } on Object catch (e) {
      debugPrint('[Auth] login() - unexpected error: $e');
      return const AuthFailedResult<User>(NetworkFailure());
    }
  }

  @override
  Future<AuthResult<User>> register({
    required String name,
    required String email,
    required String matricNumber,
    required String password,
  }) async {
    try {
      debugPrint('[Auth] register() called for $email');
      final sb.AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{
          'name': name,
          'matric_number': matricNumber,
          'role': 'student',
        },
      );

      final sb.User? sbUser = response.user;
      if (sbUser == null) {
        debugPrint('[Auth] register() - no user in response');
        return const AuthFailedResult<User>(ServerFailure('Registration failed'));
      }

      debugPrint('[Auth] register() - signUp success, uid=${sbUser.id}, session=${response.session != null}');

      // Write user profile to the `users` table.
      // NOTE: This is non-fatal — if the table doesn't exist or RLS blocks it,
      // the auth still succeeds. The profile will be built from metadata.
      try {
        await _client.from('users').upsert(<String, dynamic>{
          'id': sbUser.id,
          'name': name,
          'email': email,
          'role': 'student',
          'matric_number': matricNumber,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        debugPrint('[Auth] register() - users table upsert success');
      } on Object catch (e) {
        debugPrint('[Auth] register() - users table upsert FAILED (non-fatal): $e');
      }

      final User user = UserModel(
        id: sbUser.id,
        name: name,
        email: email,
        role: 'student',
        matricNumber: matricNumber,
      );

      await _storage.saveLastUserId(user.id);
      debugPrint('[Auth] register() - complete, returning AuthSuccess');
      return AuthSuccess<User>(user);
    } on sb.AuthException catch (e) {
      debugPrint('[Auth] register() - AuthException: ${e.message} (status: ${e.statusCode})');
      return AuthFailedResult<User>(_mapSupabaseError(e));
    } on Object catch (e) {
      debugPrint('[Auth] register() - unexpected error: $e');
      return const AuthFailedResult<User>(NetworkFailure());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } on Object {
      // Sign-out errors are non-fatal.
    }
    await _storage.clearSession();
  }

  @override
  Future<User?> getCurrentUser() async {
    final sb.User? sbUser = _client.auth.currentUser;
    if (sbUser == null) return null;
    try {
      return await _fetchOrBuildUser(sbUser).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Session is valid but profile fetch timed out — build from metadata
          // so the user stays logged in rather than being kicked to login screen.
          debugPrint('getCurrentUser: profile fetch timed out, using metadata fallback');
          final meta = sbUser.userMetadata ?? <String, dynamic>{};
          return UserModel(
            id: sbUser.id,
            name: meta['name'] as String? ?? sbUser.email ?? 'Student',
            email: sbUser.email ?? '',
            role: meta['role'] as String? ?? 'student',
            matricNumber: meta['matric_number'] as String?,
          );
        },
      );
    } on Object catch (e) {
      debugPrint('getCurrentUser error: $e');
      // Session exists but profile fetch failed — still return a user.
      final meta = sbUser.userMetadata ?? <String, dynamic>{};
      return UserModel(
        id: sbUser.id,
        name: meta['name'] as String? ?? sbUser.email ?? 'Student',
        email: sbUser.email ?? '',
        role: meta['role'] as String? ?? 'student',
        matricNumber: meta['matric_number'] as String?,
      );
    }
  }

  @override
  Future<AuthResult<User>> biometricLogin() async {
    final bool canCheck = await _localAuth.canCheckBiometrics;
    final bool isSupported = await _localAuth.isDeviceSupported();

    if (!canCheck || !isSupported) {
      return const AuthFailedResult<User>(BiometricUnavailableFailure());
    }

    final String? storedUserId = await _storage.getLastUserId();
    if (storedUserId == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }

    final bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Verify your identity to sign in to CampusConnect AUS',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );

    if (!authenticated) {
      return const AuthFailedResult<User>(BiometricCancelledFailure());
    }

    final sb.User? sbUser = _client.auth.currentUser;
    if (sbUser == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }

    try {
      final User user = await _fetchOrBuildUser(sbUser);
      return AuthSuccess<User>(user);
    } on Object {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  /// Fetches the user profile from the `users` table. Falls back to building
  /// from Supabase auth metadata if the profile row doesn't exist yet.
  Future<User> _fetchOrBuildUser(sb.User sbUser) async {
    try {
      final Map<String, dynamic>? profile = await _client
          .from('users')
          .select()
          .eq('id', sbUser.id)
          .maybeSingle();

      if (profile != null) {
        return UserModel.fromJson(<String, dynamic>{
          'id': sbUser.id,
          'name': profile['name'] as String? ?? sbUser.userMetadata?['name'] as String? ?? sbUser.email ?? 'Student',
          'email': sbUser.email ?? '',
          'role': profile['role'] as String? ?? 'student',
          'matric_number': profile['matric_number'] as String?,
          'photo_url': profile['photo_url'] as String?,
        });
      }
    } on Object {
      // Fall through to metadata-based construction.
    }

    // Fallback: construct from Supabase user metadata.
    final meta = sbUser.userMetadata ?? <String, dynamic>{};
    return UserModel(
      id: sbUser.id,
      name: meta['name'] as String? ?? sbUser.email ?? 'Student',
      email: sbUser.email ?? '',
      role: meta['role'] as String? ?? 'student',
      matricNumber: meta['matric_number'] as String?,
    );
  }

  AuthFailure _mapSupabaseError(sb.AuthException e) {
    final String msg = e.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials') || msg.contains('wrong password')) {
      return const InvalidCredentialsFailure();
    }
    if (msg.contains('user not found') || msg.contains('no user')) {
      return const UserNotFoundFailure();
    }
    if (msg.contains('already registered') || msg.contains('already in use')) {
      return const EmailAlreadyInUseFailure();
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return const NetworkFailure();
    }
    return ServerFailure(e.message);
  }
}
