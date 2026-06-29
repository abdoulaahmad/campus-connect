/// Core domain entity representing an authenticated campus actor.
///
/// This is a pure Dart class with zero external dependencies.
/// It is the single authoritative definition of a user across all layers.
///
/// All persistence layers (Firebase, SQLite, Mockoon) must map their
/// platform-specific user objects to this entity via [UserModel].
///
/// **Roles:**
/// - `student` — standard campus user with access to the student shell
/// - `admin` — campus administrator with access to the admin shell
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.matricNumber,
    this.photoUrl,
  });

  /// Firebase UID or mock ID — the system-wide unique identifier.
  final String id;

  /// Full display name of the user.
  final String name;

  /// Institutional email address (validated domain on registration).
  final String email;

  /// Role string: `'student'` or `'admin'`.
  final String role;

  /// Student matriculation number (e.g. `FCP/CIT/22/1000`).
  /// Null for admin users.
  final String? matricNumber;

  /// Optional profile photo URL from Firebase Storage.
  final String? photoUrl;

  // ── Convenience Getters ───────────────────────────────────────────────────

  /// Returns `true` if this user has the admin role.
  bool get isAdmin => role == 'admin';

  /// Returns `true` if this user has the student role.
  bool get isStudent => role == 'student';

  /// Returns the first name extracted from [name].
  String get firstName => name.split(' ').first;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'User(id: $id, name: $name, role: $role)';

  // ── CopyWith ──────────────────────────────────────────────────────────────

  /// Returns a copy of this [User] with the given fields replaced.
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? matricNumber,
    String? photoUrl,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      matricNumber: matricNumber ?? this.matricNumber,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

