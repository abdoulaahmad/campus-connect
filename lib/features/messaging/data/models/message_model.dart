import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message.dart';
import 'chat_model.dart';

/// Extension model for the [Message] domain entity.
class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.createdAt,
    required super.status,
    super.editedAt,
  });

  /// Maps a Firestore document snapshot map to [MessageModel].
  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: ChatModel.parseTimestamp(map['created_at']),
      editedAt: map['edited_at'] != null
          ? ChatModel.parseTimestamp(map['edited_at'])
          : null,
      status: _parseStatus(map['status'] as String?),
    );
  }

  /// Converts the [Message] entity into a Firestore-ready map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'created_at': Timestamp.fromDate(createdAt),
      'edited_at': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'status': status.name,
    };
  }

  static MessageStatus _parseStatus(String? value) {
    if (value == null) return MessageStatus.sent;
    return MessageStatus.values.firstWhere(
      (MessageStatus e) => e.name == value,
      orElse: () => MessageStatus.sent,
    );
  }
}
