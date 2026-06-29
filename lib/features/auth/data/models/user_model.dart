import '../../domain/entities/user.dart';

/// Data model extending [User] with JSON serialisation and
/// platform-specific factory constructors.
///
/// [UserModel] lives in the data layer and is the only class
/// allowed to parse raw JSON or Firebase objects. It converts
/// them into the pure [User] domain entity used everywhere else.
///
/// **Factories:**
/// - [UserModel.fromJson] — parses API/Mockoon JSON response
/// - [UserModel.fromFirebaseMap] — converts Firestore user document
///
/// **Usage:**
/// ```dart
/// final user = UserModel.fromJson(responseData);
/// // user is a User — no data-layer types leak out
/// ```
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.matricNumber,
    super.photoUrl,
  });

  // ── JSON Factory ──────────────────────────────────────────────────────────

  /// Constructs a [UserModel] from a JSON map (Mockoon / REST API response).
  ///
  /// Expected keys: `id`, `name`, `email`, `role`.
  /// Optional keys: `matric_number`, `photo_url`.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'student',
      matricNumber: json['matric_number'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  // ── Firestore Document Factory ────────────────────────────────────────────

  /// Constructs a [UserModel] from a Firestore user document snapshot.
  ///
  /// Requires the Firestore `users/{uid}` document to contain at minimum:
  /// `name`, `email`, `role`.
  ///
  /// The [uid] is passed separately since it's the document ID, not a field.
  factory UserModel.fromFirebaseMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      id: uid,
      name: data['name'] as String,
      email: data['email'] as String,
      role: data['role'] as String? ?? 'student',
      matricNumber: data['matric_number'] as String?,
      photoUrl: data['photo_url'] as String?,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Converts this model to a Firestore-compatible JSON map.
  ///
  /// Used when writing a new user document during registration.
  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'role': role,
      if (matricNumber != null) 'matric_number': matricNumber,
      if (photoUrl != null) 'photo_url': photoUrl,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
