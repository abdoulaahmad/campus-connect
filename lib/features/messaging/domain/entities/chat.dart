
/// Pure domain entity representing a Chat (direct or group conversation).
///
/// This is a pure Dart class with zero external dependencies.
/// All fields are immutable.
class Chat {
  const Chat({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.updatedAt,
    required this.participants,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageTime,
    this.unreadCounts = const <String, int>{},
    this.typingUsers = const <String>[],
  });

  /// Unique conversation identifier (Firestore document path or SQLite primary key).
  final String id;

  /// Conversational title (e.g. Study Group Name). Null for direct chats.
  final String? title;

  /// Returns `true` if this is a group chat; `false` if it is a 1-to-1 direct chat.
  final bool isGroup;

  /// Timestamp representing the last database edit or new message (UTC).
  final DateTime updatedAt;

  /// List of participant user IDs.
  final List<String> participants;

  /// Text content snippet of the last sent message.
  final String? lastMessageText;

  /// Sender UID of the last message.
  final String? lastMessageSenderId;

  /// Timestamp of the last sent message (UTC).
  final DateTime? lastMessageTime;

  /// Map tracking unread message counts for each participant user ID.
  final Map<String, int> unreadCounts;

  /// List of user IDs currently typing in this chat room.
  final List<String> typingUsers;

  /// Helper to get the display title of the conversation.
  ///
  /// If direct chat, it falls back to the peer user's display name
  /// (usually resolved at presentation layer using the peer name).
  String getDisplayTitle(String currentUserId) {
    if (isGroup) {
      return title ?? 'Unnamed Group';
    }
    return 'Chat';
  }

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chat &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isGroup == other.isGroup &&
          updatedAt.isAtSameMomentAs(other.updatedAt) &&
          lastMessageText == other.lastMessageText &&
          lastMessageSenderId == other.lastMessageSenderId &&
          (lastMessageTime == null && other.lastMessageTime == null ||
              lastMessageTime != null &&
                  other.lastMessageTime != null &&
                  lastMessageTime!.isAtSameMomentAs(other.lastMessageTime!)));

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      isGroup.hashCode ^
      updatedAt.hashCode ^
      lastMessageText.hashCode ^
      lastMessageSenderId.hashCode ^
      lastMessageTime.hashCode;

  @override
  String toString() =>
      'Chat(id: $id, title: $title, isGroup: $isGroup, updatedAt: $updatedAt)';

  // ── CopyWith ──────────────────────────────────────────────────────────────

  /// Returns a copy of this [Chat] with the given fields replaced.
  Chat copyWith({
    String? id,
    String? title,
    bool? isGroup,
    DateTime? updatedAt,
    List<String>? participants,
    String? lastMessageText,
    String? lastMessageSenderId,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCounts,
    List<String>? typingUsers,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      isGroup: isGroup ?? this.isGroup,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}
