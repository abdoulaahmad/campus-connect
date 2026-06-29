/// Status lifecycle of a message delivery.
enum MessageStatus {
  /// Local client has created the message, writing is pending.
  sending,

  /// Message successfully written to Firestore.
  sent,

  /// Recipient client stream has received the message snapshot.
  delivered,

  /// Recipient has opened the chat room and marked it read.
  read,

  /// Message failed to write due to network/rules/other issues.
  failed,
}

/// Pure domain entity representing an individual chat message.
///
/// This is a pure Dart class with zero external dependencies.
/// All fields except runtime checks are immutable.
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    required this.status,
    this.editedAt,
  });

  /// Unique message document identifier.
  final String id;

  /// UID of the user who sent this message.
  final String senderId;

  /// Visual display name of the sender.
  final String senderName;

  /// Raw text content of the message.
  final String content;

  /// Timestamp representing when the message was sent (UTC).
  final DateTime createdAt;

  /// Timestamp representing when the message was last updated/edited (UTC).
  /// Null if the message was never edited.
  final DateTime? editedAt;

  /// Current delivery/read lifecycle status.
  final MessageStatus status;

  /// Returns `true` if the message was edited at least once.
  bool get isEdited => editedAt != null;

  /// Client-side enforcement of the Group 11 unique edit rule constraint.
  ///
  /// Returns `true` if the current time is within 120 seconds of [createdAt].
  /// Device clock comparisons are done in UTC to avoid time-zone offsets.
  bool get isEditable =>
      DateTime.now().toUtc().difference(createdAt).inSeconds <= 120;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderId == other.senderId &&
          senderName == other.senderName &&
          content == other.content &&
          createdAt.isAtSameMomentAs(other.createdAt) &&
          status == other.status &&
          (editedAt == null && other.editedAt == null ||
              editedAt != null &&
                  other.editedAt != null &&
                  editedAt!.isAtSameMomentAs(other.editedAt!)));

  @override
  int get hashCode =>
      id.hashCode ^
      senderId.hashCode ^
      senderName.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      status.hashCode ^
      editedAt.hashCode;

  @override
  String toString() =>
      'Message(id: $id, senderName: $senderName, status: $status, content: $content)';

  // ── CopyWith ──────────────────────────────────────────────────────────────

  /// Returns a copy of this [Message] with the given fields replaced.
  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? createdAt,
    DateTime? editedAt,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      status: status ?? this.status,
    );
  }
}
