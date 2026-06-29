import 'dart:convert';

import 'package:flutter/services.dart';

import 'environment.dart';

/// Central application configuration for CampusConnect AUS.
///
/// Loads and validates `assets/config/config.json` at boot time.
/// Exposes typed constants used across the entire application.
///
/// **Usage:**
/// ```dart
/// await AppConfig.initialize();
/// print(AppConfig.campusCode); // 'CAM-AUS-11'
/// ```
///
/// **Boot Halt:** The app halts immediately (via [AssertionError]) if:
/// - `campus_code` != `CAM-AUS-11`
/// - `api_base_path` != `/api/v2/aus/`
/// - `ENV` dart-define is not one of `prod`, `dev`, `test`
abstract final class AppConfig {
  // ── Expected Values (Immutable) ──────────────────────────────────────────

  static const String _expectedCampusCode = 'CAM-AUS-11';
  static const String _expectedApiBasePath = '/api/v2/aus/';
  static const List<String> _validEnvValues = ['prod', 'dev', 'test'];

  /// The ENV value passed via `--dart-define=ENV=`. Defaults to `dev`.
  static const String _envString =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  // ── Resolved Runtime Fields ───────────────────────────────────────────────

  /// The campus code loaded from config.json. Must equal `CAM-AUS-11`.
  static late String campusCode;

  /// The API base path loaded from config.json. Must equal `/api/v2/aus/`.
  static late String apiBasePath;

  /// Human-readable version string from config.json.
  static late String version;

  /// The resolved [Environment] for this build.
  static late Environment environment;

  /// Base URL for the Mockoon mock server used in [Environment.dev].
  ///
  /// Resolves standard Android emulator host (`10.0.2.2`) which maps
  /// to `localhost` on the development machine. Can be overridden via
  /// --dart-define=API_URL for real physical devices.
  static const String mockoonBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v2/aus/',
  );

  // ── Initialization ────────────────────────────────────────────────────────

  /// Loads `assets/config/config.json` and validates all required fields.
  ///
  /// Must be called **before** [runApp] in `main()`. Throws [StateError]
  /// if any field is missing from the JSON. Triggers [AssertionError] in
  /// debug mode on any validation mismatch (halts boot).
  static Future<void> initialize() async {
    // Step 1: Validate ENV dart-define before touching any file.
    assert(
      _validEnvValues.contains(_envString),
      'AppConfig: Invalid ENV value "$_envString". '
      'Must be one of: prod, dev, test — boot halted.',
    );

    environment = Environment.values.byName(_envString);

    // Step 2: Load and parse config.json from bundled assets.
    final String raw =
        await rootBundle.loadString('assets/config/config.json');

    final Map<String, dynamic> json =
        jsonDecode(raw) as Map<String, dynamic>;

    // Step 3: Extract fields with null-safety guards.
    campusCode = _requireField<String>(json, 'campus_code');
    apiBasePath = _requireField<String>(json, 'api_base_path');
    version = _requireField<String>(json, 'version');

    // Step 4: Validate campus code against expected constant.
    assert(
      campusCode == _expectedCampusCode,
      'AppConfig: Invalid campus_code "$campusCode". '
      'Expected "$_expectedCampusCode" — boot halted.',
    );

    // Step 5: Validate API base path against expected constant.
    assert(
      apiBasePath == _expectedApiBasePath,
      'AppConfig: Invalid api_base_path "$apiBasePath". '
      'Expected "$_expectedApiBasePath" — boot halted.',
    );
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  /// Extracts a required typed field from [json].
  ///
  /// Throws [StateError] if the key is absent or the value is not of type [T].
  static T _requireField<T>(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      throw StateError(
        'AppConfig: Required field "$key" is missing from config.json.',
      );
    }
    if (value is! T) {
      throw StateError(
        'AppConfig: Field "$key" must be of type $T but was ${value.runtimeType}.',
      );
    }
    return value as T;
  }
}
