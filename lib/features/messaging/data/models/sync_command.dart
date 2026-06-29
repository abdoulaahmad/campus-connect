import 'dart:convert';

class SyncCommand {
  const SyncCommand({
    this.id,
    required this.commandType,
    required this.chatId,
    this.messageId,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
  });

  final int? id;
  final String commandType; // 'sendMessage' | 'editMessage' | 'markAsRead'
  final String chatId;
  final String? messageId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;

  SyncCommand copyWith({
    int? id,
    String? commandType,
    String? chatId,
    String? messageId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? attemptCount,
    String? lastError,
  }) {
    return SyncCommand(
      id: id ?? this.id,
      commandType: commandType ?? this.commandType,
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'command_type': commandType,
      'chat_id': chatId,
      'message_id': messageId,
      'payload': jsonEncode(payload),
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'attempt_count': attemptCount,
      'last_error': lastError,
    };
  }

  factory SyncCommand.fromMap(Map<String, dynamic> map) {
    return SyncCommand(
      id: map['id'] as int?,
      commandType: map['command_type'] as String,
      chatId: map['chat_id'] as String,
      messageId: map['message_id'] as String?,
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int, isUtc: true),
      attemptCount: map['attempt_count'] as int,
      lastError: map['last_error'] as String?,
    );
  }
}
