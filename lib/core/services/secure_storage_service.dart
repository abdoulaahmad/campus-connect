import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure key-value storage service for sensitive session metadata.
///
/// Wraps [FlutterSecureStorage] with typed accessors for the three
/// values CampusConnect AUS stores between sessions:
///
/// | Key | Type | Purpose |
/// |-----|------|---------|
/// | `last_logged_in_user_id` | String | Biometric recovery — used to re-fetch user after biometric success |
/// | `preferred_biometric_login` | bool | Whether the user opted in to biometric login |
/// | `remember_me` | bool | Whether to attempt session restore on next launch |
///
/// **What is NOT stored here:**
/// - Firebase ID tokens (Firebase SDK manages these internally)
/// - Passwords (never stored anywhere)
/// - Full user objects (stored in Firestore / in-memory cache)
///
/// **Platform notes:**
/// - Android: Uses Android Keystore (AES-256 encryption)
/// - iOS: Uses iOS Keychain
/// - Requires API 18+ on Android (minSdk is 21 — satisfied)
class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// For testing — allows injecting a custom storage instance.
  const SecureStorageService.custom(this._storage);

  final FlutterSecureStorage _storage;

  // ── Keys (private — never exposed as raw strings outside this class) ───────

  static const String _keyLastUserId = 'last_logged_in_user_id';
  static const String _keyBiometricEnabled = 'preferred_biometric_login';
  static const String _keyRememberMe = 'remember_me';

  // ── Last Logged-In User ID ────────────────────────────────────────────────

  /// Persists the last successfully authenticated user's ID.
  ///
  /// Called after every successful login. Used by [FirebaseAuthRepository]
  /// to re-hydrate the user object after biometric authentication.
  Future<void> saveLastUserId(String userId) async {
    await _storage.write(key: _keyLastUserId, value: userId);
  }

  /// Returns the last logged-in user ID, or `null` if not set.
  Future<String?> getLastUserId() async {
    return _storage.read(key: _keyLastUserId);
  }

  // ── Biometric Preference ──────────────────────────────────────────────────

  /// Persists the user's biometric login preference.
  Future<void> setBiometricEnabled({required bool enabled}) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled.toString(),
    );
  }

  /// Returns `true` if the user opted in to biometric login.
  Future<bool> isBiometricEnabled() async {
    final String? value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  // ── Remember Me ───────────────────────────────────────────────────────────

  /// Persists the "remember me" session preference.
  Future<void> setRememberMe({required bool remember}) async {
    await _storage.write(key: _keyRememberMe, value: remember.toString());
  }

  /// Returns `true` if the user opted to persist their session.
  Future<bool> getRememberMe() async {
    final String? value = await _storage.read(key: _keyRememberMe);
    return value == 'true';
  }

  // ── Clear Session ─────────────────────────────────────────────────────────

  /// Removes all stored session metadata.
  ///
  /// Called by [LogoutUseCase] via the repository. Does not delete
  /// device-level biometric enrollment — only app preferences.
  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
