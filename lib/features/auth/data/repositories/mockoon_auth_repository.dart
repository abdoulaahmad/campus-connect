import 'package:dio/dio.dart';
import 'package:local_auth/local_auth.dart';

import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Mockoon dev-server [IAuthRepository] implementation for `ENV=dev`.
///
/// Sends HTTP requests to the local Mockoon mock API server at
/// `http://10.0.2.2:3000/api/v2/aus/`. This simulates the Firebase
/// backend without requiring Firebase configuration.
///
/// **Mockoon API endpoints used:**
/// - `POST /auth/login` → `{ user: UserJson }`
/// - `POST /auth/register` → `{ user: UserJson }`
/// - `GET  /auth/me` → `UserJson | 404`
///
/// **Note:** Mockoon must be running on the development machine for
/// requests to succeed. The emulator's `10.0.2.2` routes to `localhost`.
class MockoonAuthRepository implements IAuthRepository {
  MockoonAuthRepository({
    required Dio dio,
    required SecureStorageService storage,
    LocalAuthentication? localAuth,
  })  : _dio = dio,
        _storage = storage,
        _localAuth = localAuth ?? LocalAuthentication();

  final Dio _dio;
  final SecureStorageService _storage;
  final LocalAuthentication _localAuth;

  // Cached in-memory user for getCurrentUser without an extra network call.
  User? _cachedUser;

  @override
  Future<AuthResult<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, String>{'email': email, 'password': password},
      );

      final Map<String, dynamic>? data = response.data;
      if (data == null || data['user'] == null) {
        return const AuthFailedResult<User>(ServerFailure('Empty response'));
      }

      final User user = UserModel.fromJson(
        data['user'] as Map<String, dynamic>,
      );
      _cachedUser = user;
      await _storage.saveLastUserId(user.id);
      return AuthSuccess<User>(user);
    } on DioException catch (e) {
      return AuthFailedResult<User>(_mapDioError(e));
    } on Object {
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
      final Response<Map<String, dynamic>> response =
          await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: <String, String>{
          'name': name,
          'email': email,
          'matric_number': matricNumber,
          'password': password,
          'role': 'student',
        },
      );

      final Map<String, dynamic>? data = response.data;
      if (data == null || data['user'] == null) {
        return const AuthFailedResult<User>(ServerFailure('Empty response'));
      }

      final User user = UserModel.fromJson(
        data['user'] as Map<String, dynamic>,
      );
      _cachedUser = user;
      await _storage.saveLastUserId(user.id);
      return AuthSuccess<User>(user);
    } on DioException catch (e) {
      return AuthFailedResult<User>(_mapDioError(e));
    } on Object {
      return const AuthFailedResult<User>(NetworkFailure());
    }
  }

  @override
  Future<void> logout() async {
    _cachedUser = null;
    await _storage.clearSession();
  }

  @override
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;

    final String? storedId = await _storage.getLastUserId();
    if (storedId == null) return null;

    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>('/auth/me');
      final Map<String, dynamic>? data = response.data;
      if (data == null) return null;
      _cachedUser = UserModel.fromJson(data);
      return _cachedUser;
    } on Object {
      return null;
    }
  }

  @override
  Future<AuthResult<User>> biometricLogin() async {
    final bool canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) {
      return const AuthFailedResult<User>(BiometricUnavailableFailure());
    }

    final String? storedUserId = await _storage.getLastUserId();
    if (storedUserId == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }

    final bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Sign in to CampusConnect AUS',
      options: const AuthenticationOptions(biometricOnly: true),
    );

    if (!authenticated) {
      return const AuthFailedResult<User>(BiometricCancelledFailure());
    }

    final User? user = _cachedUser;
    if (user == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }

    return AuthSuccess<User>(user);
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  AuthFailure _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkFailure();
    }
    final int? status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return const InvalidCredentialsFailure();
    }
    if (status == 404) {
      return const UserNotFoundFailure();
    }
    if (status == 409) {
      return const EmailAlreadyInUseFailure();
    }
    return ServerFailure('HTTP $status');
  }
}
