/// Defines the runtime environment for CampusConnect AUS.
///
/// Resolved at application startup via `--dart-define=ENV=prod|dev|test`.
/// Used throughout the app to switch between repository implementations
/// without modifying any business logic.
///
/// See [AppConfig.environment] for the resolved instance.
enum Environment {
  /// Production environment.
  ///
  /// Binds all repository slots to live Google Firebase cloud services.
  /// FCM push notifications, Firestore real-time streams, and Firebase Auth
  /// are all active. Seed data scripts are **disabled** in this environment.
  prod,

  /// Development environment.
  ///
  /// Points all HTTP-based repositories to a local Mockoon mock server
  /// running at `http://10.0.2.2:3000/api/v2/aus/` (standard Android/iOS
  /// emulator host alias). Firestore is replaced with Mockoon REST endpoints.
  dev,

  /// Testing environment.
  ///
  /// Uses pure in-memory mock repositories with no external dependencies.
  /// Suitable for unit and integration tests. No network calls are made.
  test,
}
