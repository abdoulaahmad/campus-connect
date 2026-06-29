
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/services/secure_storage_service.dart';

/// In-memory [IAuthRepository] implementation for `ENV=test`.
///
/// Contains two hardcoded fixture users. No network calls, no Firebase.
/// Used in widget tests and integration tests to remove external dependencies.
///
/// **Test credentials:**
/// | Email | Password | Role |
/// |-------|----------|------|
/// | `student@university.edu` | `student123` | student |
/// | `admin@university.edu` | `admin123` | admin |
class MockAuthRepository implements IAuthRepository {
  MockAuthRepository({required SecureStorageService storage})
      : _storage = storage;

  final SecureStorageService _storage;

  // Fixture users — MR-008: only in dev/test, never in prod.
  static final List<Map<String, String>> _fixtures = <Map<String, String>>[
    <String, String>{
      'id': 'student_001',
      'name': 'Abdullahi Abba Ahmad',
      'email': 'student@university.edu',
      'password': 'student123',
      'role': 'student',
      'matric_number': 'FCP/CIT/22/1000',
    },
    <String, String>{
      'id': 'admin_001',
      'name': 'System Administrator',
      'email': 'admin@university.edu',
      'password': 'admin123',
      'role': 'admin',
    },
  ];

  // Simulated in-memory session.
  User? _currentUser;

  @override
  Future<AuthResult<User>> login({
    required String email,
    required String password,
  }) async {
    // Simulate a realistic async delay.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final Map<String, String>? fixture = _fixtures.where(
      (Map<String, String> f) =>
          f['email'] == email && f['password'] == password,
    ).firstOrNull;

    if (fixture == null) {
      return const AuthFailedResult<User>(InvalidCredentialsFailure());
    }

    final User user = UserModel(
      id: fixture['id']!,
      name: fixture['name']!,
      email: fixture['email']!,
      role: fixture['role']!,
      matricNumber: fixture['matric_number'],
    );

    _currentUser = user;
    await _storage.saveLastUserId(user.id);
    return AuthSuccess<User>(user);
  }

  @override
  Future<AuthResult<User>> register({
    required String name,
    required String email,
    required String matricNumber,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final bool exists = _fixtures.any(
      (Map<String, String> f) => f['email'] == email,
    );

    if (exists) {
      return const AuthFailedResult<User>(EmailAlreadyInUseFailure());
    }

    final User user = UserModel(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: 'student',
      matricNumber: matricNumber,
    );

    _currentUser = user;
    await _storage.saveLastUserId(user.id);
    return AuthSuccess<User>(user);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    await _storage.clearSession();
  }

  @override
  Future<User?> getCurrentUser() async => _currentUser;

  @override
  Future<AuthResult<User>> biometricLogin() async {
    // In test environment, biometric always succeeds if a user is stored.
    final User? user = _currentUser;
    if (user == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }
    return AuthSuccess<User>(user);
  }
}
