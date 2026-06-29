/// Pure domain entity representing a participant in a chat room.
///
/// This is a pure Dart class with zero external dependencies.
/// Tracks membership info, roles, and read receipts.
class ChatMember {
  const ChatMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.lastReadAt,
  });

  /// Unique user ID matching the [User.id].
  final String userId;

  /// Member's role in the chat: `'owner'` or `'member'`.
  final String role;

  /// Timestamp when the user joined the conversation (converted/stored in UTC).
  final DateTime joinedAt;

  /// Timestamp of the last message read by the user in this conversation (UTC).
  final DateTime lastReadAt;

  /// Returns `true` if this user is the owner/creator of the group chat.
  bool get isOwner => role == 'owner';

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMember &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          role == other.role &&
          joinedAt.isAtSameMomentAs(other.joinedAt) &&
          lastReadAt.isAtSameMomentAs(other.lastReadAt));

  @override
  int get hashCode =>
      userId.hashCode ^ role.hashCode ^ joinedAt.hashCode ^ lastReadAt.hashCode;

  @override
  String toString() =>
      'ChatMember(userId: $userId, role: $role, lastReadAt: $lastReadAt)';

  // ── CopyWith ──────────────────────────────────────────────────────────────

  /// Returns a copy of this [ChatMember] with the given fields replaced.
  ChatMember copyWith({
    String? userId,
    String? role,
    DateTime? joinedAt,
    DateTime? lastReadAt,
  }) {
    return ChatMember(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
