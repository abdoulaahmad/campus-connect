import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:local_auth/local_auth.dart';

import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/user_model.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Production [IAuthRepository] implementation using Firebase Authentication.
///
/// **Prerequisites:** `google-services.json` must be present in `android/app/`
/// and `GoogleService-Info.plist` in `ios/Runner/` before this repository
/// can authenticate against live Firebase. Resolves RISK-001.
///
/// **Session management:** Firebase SDK persists the session automatically.
/// This class does NOT store Firebase ID tokens manually. It only writes
/// `last_logged_in_user_id` to [SecureStorageService] after successful login
/// to support biometric recovery.
///
/// **Firestore:** This implementation reads the `users/{uid}` document to get
/// the role and matric number. Sprint 1 uses a simplified approach that
/// constructs a basic User from FirebaseAuth data. Full Firestore integration
/// comes in Sprint 3.
class FirebaseAuthRepository implements IAuthRepository {
  FirebaseAuthRepository({
    required SecureStorageService storage,
    fb.FirebaseAuth? firebaseAuth,
    LocalAuthentication? localAuth,
  })  : _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _storage = storage,
        _localAuth = localAuth ?? LocalAuthentication();

  final fb.FirebaseAuth _auth;
  final SecureStorageService _storage;
  final LocalAuthentication _localAuth;

  @override
  Future<AuthResult<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final fb.UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fb.User? fbUser = credential.user;
      if (fbUser == null) {
        return const AuthFailedResult<User>(ServerFailure('No user in credential'));
      }

      final User user = _mapFirebaseUser(fbUser);
      await _storage.saveLastUserId(user.id);
      return AuthSuccess<User>(user);
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailedResult<User>(_mapFirebaseError(e));
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
      final fb.UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fb.User? fbUser = credential.user;
      if (fbUser == null) {
        return const AuthFailedResult<User>(ServerFailure('Registration failed'));
      }

      // Update display name immediately after creation.
      await fbUser.updateDisplayName(name);

      // Sprint 3: Write full user document to Firestore here.
      // For now, construct user from Firebase data.
      final User user = UserModel(
        id: fbUser.uid,
        name: name,
        email: email,
        role: 'student',
        matricNumber: matricNumber,
      );

      await _storage.saveLastUserId(user.id);
      return AuthSuccess<User>(user);
    } on fb.FirebaseAuthException catch (e) {
      return AuthFailedResult<User>(_mapFirebaseError(e));
    } on Object {
      return const AuthFailedResult<User>(NetworkFailure());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } on Object {
      // Firebase sign-out errors are non-fatal — always proceed.
    }
    await _storage.clearSession();
  }

  @override
  Future<User?> getCurrentUser() async {
    final fb.User? fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    return _mapFirebaseUser(fbUser);
  }

  @override
  Future<AuthResult<User>> biometricLogin() async {
    // Step 1: Check biometric availability.
    final bool canCheck = await _localAuth.canCheckBiometrics;
    final bool isDeviceSupported = await _localAuth.isDeviceSupported();

    if (!canCheck || !isDeviceSupported) {
      return const AuthFailedResult<User>(BiometricUnavailableFailure());
    }

    // Step 2: Check stored user ID.
    final String? storedUserId = await _storage.getLastUserId();
    if (storedUserId == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }

    // Step 3: Trigger OS biometric prompt.
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

    // Step 4: Biometric success — return current Firebase user.
    final fb.User? fbUser = _auth.currentUser;
    if (fbUser == null) {
      return const AuthFailedResult<User>(UserNotFoundFailure());
    }

    return AuthSuccess<User>(_mapFirebaseUser(fbUser));
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  User _mapFirebaseUser(fb.User fbUser) {
    return UserModel(
      id: fbUser.uid,
      name: fbUser.displayName ?? fbUser.email ?? 'Student',
      email: fbUser.email ?? '',
      role: 'student', // Sprint 3: Read from Firestore users/{uid}.role
    );
  }

  AuthFailure _mapFirebaseError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const UserNotFoundFailure();
      case 'wrong-password':
      case 'invalid-credential':
        return const InvalidCredentialsFailure();
      case 'email-already-in-use':
        return const EmailAlreadyInUseFailure();
      case 'network-request-failed':
        return const NetworkFailure();
      default:
        return ServerFailure(e.message ?? 'Unknown Firebase error');
    }
  }
}
