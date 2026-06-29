import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_member.dart';

/// Extension model for the [Chat] domain entity to handle serialization.
class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.title,
    required super.isGroup,
    required super.updatedAt,
    required super.participants,
    super.lastMessageText,
    super.lastMessageSenderId,
    super.lastMessageTime,
    super.unreadCounts,
    super.typingUsers,
  });

  /// Maps a Firestore document or API JSON map to the [ChatModel] entity.
  ///
  /// Coerces all timestamps to UTC.
  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    final rawParticipants = map['participants'] as List? ?? <dynamic>[];
    final rawTyping = map['typing_users'] as List? ?? <dynamic>[];
    
    return ChatModel(
      id: id,
      title: map['title'] as String?,
      isGroup: map['is_group'] as bool? ?? false,
      updatedAt: parseTimestamp(map['updated_at']),
      participants: rawParticipants.map((dynamic e) => e.toString()).toList(),
      lastMessageText: map['last_message_text'] as String?,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      lastMessageTime: map['last_message_time'] != null
          ? parseTimestamp(map['last_message_time'])
          : null,
      unreadCounts: Map<String, int>.from(
        (map['unread_counts'] as Map?)?.map(
              (dynamic k, dynamic v) => MapEntry<String, int>(
                k.toString(),
                int.tryParse(v.toString()) ?? 0,
              ),
            ) ??
            <dynamic, dynamic>{},
      ),
      typingUsers: rawTyping.map((dynamic e) => e.toString()).toList(),
    );
  }

  /// Converts the [Chat] entity into a Firestore-ready update map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'is_group': isGroup,
      'updated_at': Timestamp.fromDate(updatedAt),
      'participants': participants,
      'last_message_text': lastMessageText,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_time': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unread_counts': unreadCounts,
      'typing_users': typingUsers,
    };
  }

  /// Safe helper to parse varied timestamp formats (Firestore [Timestamp], ISO [String], epoch [int]) into UTC [DateTime].
  static DateTime parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return DateTime.now().toUtc();
  }
}

/// Extension model for the [ChatMember] domain entity.
class ChatMemberModel extends ChatMember {
  const ChatMemberModel({
    required super.userId,
    required super.role,
    required super.joinedAt,
    required super.lastReadAt,
  });

  /// Maps a member document snapshot map to [ChatMemberModel].
  factory ChatMemberModel.fromMap(String userId, Map<String, dynamic> map) {
    return ChatMemberModel(
      userId: userId,
      role: map['role'] as String? ?? 'member',
      joinedAt: ChatModel.parseTimestamp(map['joined_at']),
      lastReadAt: ChatModel.parseTimestamp(map['last_read_at']),
    );
  }

  /// Converts the [ChatMember] entity into a database-ready map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'role': role,
      'joined_at': Timestamp.fromDate(joinedAt),
      'last_read_at': Timestamp.fromDate(lastReadAt),
    };
  }
}
