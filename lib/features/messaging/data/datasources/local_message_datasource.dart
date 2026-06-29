import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../models/sync_command.dart';

class LocalMessageDatasource {
  const LocalMessageDatasource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  // ── Chat Caching ──────────────────────────────────────────────────────────

  Future<void> cacheChats(List<Chat> chats) async {
    final db = await _db;
    final batch = db.batch();

    // Clear old cached chats to keep lists synchronized
    batch.delete('cached_chats');

    for (final chat in chats) {
      batch.insert(
        'cached_chats',
        {
          'id': chat.id,
          'title': chat.title,
          'is_group': chat.isGroup ? 1 : 0,
          'updated_at': chat.updatedAt.toUtc().millisecondsSinceEpoch,
          'participants': jsonEncode(chat.participants),
          'last_message_text': chat.lastMessageText,
          'last_message_sender_id': chat.lastMessageSenderId,
          'last_message_time': chat.lastMessageTime?.toUtc().millisecondsSinceEpoch,
          'unread_counts': jsonEncode(chat.unreadCounts),
          'typing_users': jsonEncode(chat.typingUsers),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chat>> getCachedChats() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_chats',
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) {
      final participantsList = jsonDecode(map['participants'] as String) as List;
      final typingList = jsonDecode(map['typing_users'] as String) as List;
      final unreadMap = jsonDecode(map['unread_counts'] as String) as Map;

      return Chat(
        id: map['id'] as String,
        title: map['title'] as String?,
        isGroup: (map['is_group'] as int) == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int, isUtc: true),
        participants: participantsList.map((e) => e.toString()).toList(),
        lastMessageText: map['last_message_text'] as String?,
        lastMessageSenderId: map['last_message_sender_id'] as String?,
        lastMessageTime: map['last_message_time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_message_time'] as int, isUtc: true)
            : null,
        unreadCounts: Map<String, int>.from(
          unreadMap.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0)),
        ),
        typingUsers: typingList.map((e) => e.toString()).toList(),
      );
    }).toList();
  }

  // ── Message Caching ───────────────────────────────────────────────────────

  Future<void> cacheMessages(String chatId, List<Message> messages) async {
    final db = await _db;
    final batch = db.batch();

    // Cache message details (upsert)
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final msg in messages) {
      batch.insert(
        'cached_messages',
        {
          'id': msg.id,
          'chat_id': chatId,
          'sender_id': msg.senderId,
          'sender_name': msg.senderName,
          'content': msg.content,
          'status': msg.status.name,
          'created_at': msg.createdAt.toUtc().millisecondsSinceEpoch,
          'edited_at': msg.editedAt?.toUtc().millisecondsSinceEpoch,
          'synced_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Message>> getCachedMessages(String chatId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) {
      return Message(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        senderName: map['sender_name'] as String,
        content: map['content'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int, isUtc: true),
        status: MessageStatus.values.firstWhere(
          (e) => e.name == map['status'] as String,
          orElse: () => MessageStatus.sent,
        ),
        editedAt: map['edited_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['edited_at'] as int, isUtc: true)
            : null,
      );
    }).toList();
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final db = await _db;
    await db.update(
      'cached_messages',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ── Sync Queue ────────────────────────────────────────────────────────────

  Future<void> enqueueCommand(SyncCommand command) async {
    final db = await _db;
    await db.insert(
      'sync_queue',
      command.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncCommand>> getPendingCommands() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      orderBy: 'id ASC',
    );
    return maps.map((map) => SyncCommand.fromMap(map)).toList();
  }

  Future<void> markCommandSuccess(int id) async {
    final db = await _db;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementCommandAttempt(int id, String error) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final cmd = SyncCommand.fromMap(maps.first);
      await db.update(
        'sync_queue',
        {
          'attempt_count': cmd.attemptCount + 1,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> removeCommand(int id) async {
    final db = await _db;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
