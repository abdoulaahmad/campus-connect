import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/repositories/i_chat_repository.dart';

/// Production [IChatRepository] implementation using Supabase Postgres + Realtime.
///
/// Table schema (see supabase_schema.sql):
/// - `chats` — id, participants (uuid[]), last_message_text, last_message_sender_id,
///             last_message_time, updated_at, unread_counts (jsonb)
/// - `messages` — id, chat_id, sender_id, sender_name, content, status,
///               created_at, edited_at
/// - `typing_indicators` — chat_id, user_id, is_typing, updated_at (PK: chat_id+user_id)
/// - `chat_members` — chat_id, user_id, last_read_at
///
/// Realtime subscriptions are used for messages and typing. Chat list uses
/// Postgres changes on the `chats` table filtered by the participants array.
class SupabaseChatRepository implements IChatRepository {
  SupabaseChatRepository({sb.SupabaseClient? client})
      : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  String? get _currentUid => _client.auth.currentUser?.id;

  // ── streamChats ────────────────────────────────────────────────────────────

  @override
  Stream<List<Chat>> streamChats() {
    final uid = _currentUid;
    if (uid == null) return Stream.value(const <Chat>[]);

    final controller = StreamController<List<Chat>>();

    Future<void> fetch() async {
      try {
        final data = await _client
            .from('chats')
            .select()
            .contains('participants', <String>[uid])
            .order('updated_at', ascending: false);

        final chats = (data as List<dynamic>)
            .map((e) => _chatFromRow(e as Map<String, dynamic>))
            .toList();
        if (!controller.isClosed) controller.add(chats);
      } catch (e) {
        if (!controller.isClosed) controller.add(<Chat>[]);
      }
    }

    fetch();

    final subscription = _client
        .channel('chats:$uid')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      subscription.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  // ── streamMessages ─────────────────────────────────────────────────────────

  @override
  Stream<List<Message>> streamMessages(String chatId) {
    final uid = _currentUid;
    final controller = StreamController<List<Message>>();

    Future<void> fetch() async {
      try {
        final data = await _client
            .from('messages')
            .select()
            .eq('chat_id', chatId)
            .order('created_at', ascending: true);

        final messages = (data as List<dynamic>)
            .map((e) => _messageFromRow(e as Map<String, dynamic>))
            .toList();

        if (!controller.isClosed) controller.add(messages);

        // Mark incoming messages as delivered in the background.
        if (uid != null) {
          _markDelivered(chatId, messages, uid);
        }
      } catch (e) {
        if (!controller.isClosed) controller.add(<Message>[]);
      }
    }

    fetch();

    final subscription = _client
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      subscription.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  // ── sendMessage ────────────────────────────────────────────────────────────

  @override
  Future<ChatResult<void>> sendMessage(String chatId, Message message) async {
    try {
      final uid = _currentUid;
      if (uid == null) return const ChatFailedResult(PermissionDeniedFailure());

      // Insert the message row.
      await _client.from('messages').insert(<String, dynamic>{
        'id': message.id,
        'chat_id': chatId,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'content': message.content,
        'status': MessageStatus.sent.name,
        'created_at': message.createdAt.toUtc().toIso8601String(),
      });

      // Update the chat preview and unread counts via RPC.
      await _client.rpc('increment_unread_and_update_preview', params: <String, dynamic>{
        'p_chat_id': chatId,
        'p_sender_id': message.senderId,
        'p_content': message.content,
        'p_sent_at': message.createdAt.toUtc().toIso8601String(),
      });

      return const ChatSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      if (e.code == '42501') return const ChatFailedResult(PermissionDeniedFailure());
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  // ── editMessage ────────────────────────────────────────────────────────────

  @override
  Future<ChatResult<void>> editMessage(
      String chatId, String messageId, String newContent) async {
    try {
      // Fetch the message to validate edit window.
      final rows = await _client
          .from('messages')
          .select()
          .eq('id', messageId)
          .eq('chat_id', chatId)
          .limit(1);

      final List<dynamic> list = rows as List<dynamic>;
      if (list.isEmpty) {
        return const ChatFailedResult(MessageSendFailure('Message not found'));
      }

      final msg = _messageFromRow(list.first as Map<String, dynamic>);
      if (!msg.isEditable) {
        return const ChatFailedResult(MessageEditExpiredFailure());
      }

      final now = DateTime.now().toUtc();
      await _client.from('messages').update(<String, dynamic>{
        'content': newContent,
        'edited_at': now.toIso8601String(),
      }).eq('id', messageId);

      return const ChatSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      if (e.code == '42501') return const ChatFailedResult(PermissionDeniedFailure());
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  // ── setTyping ──────────────────────────────────────────────────────────────

  @override
  Future<ChatResult<void>> setTyping(String chatId, bool isTyping) async {
    try {
      final uid = _currentUid;
      if (uid == null) return const ChatFailedResult(PermissionDeniedFailure());

      await _client.from('typing_indicators').upsert(<String, dynamic>{
        'chat_id': chatId,
        'user_id': uid,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'chat_id,user_id');

      return const ChatSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  // ── streamTypingUsers ──────────────────────────────────────────────────────

  @override
  Stream<List<String>> streamTypingUsers(String chatId) {
    final uid = _currentUid;
    final controller = StreamController<List<String>>();

    Future<void> fetch() async {
      try {
        final data = await _client
            .from('typing_indicators')
            .select()
            .eq('chat_id', chatId)
            .eq('is_typing', true);

        final now = DateTime.now().toUtc();
        final typers = <String>[];
        for (final row in data as List<dynamic>) {
          final rowMap = row as Map<String, dynamic>;
          final rowUid = rowMap['user_id'] as String;
          if (rowUid == uid) continue;

          final updatedAt = _parseDateTime(rowMap['updated_at']);
          if (now.difference(updatedAt).inSeconds <= 15) {
            typers.add(rowUid);
          }
        }
        if (!controller.isClosed) controller.add(typers);
      } catch (_) {
        if (!controller.isClosed) controller.add(<String>[]);
      }
    }

    fetch();

    final subscription = _client
        .channel('typing:$chatId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_indicators',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      subscription.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  // ── markAsRead ─────────────────────────────────────────────────────────────

  @override
  Future<ChatResult<void>> markAsRead(String chatId) async {
    try {
      final uid = _currentUid;
      if (uid == null) return const ChatFailedResult(PermissionDeniedFailure());

      final now = DateTime.now().toUtc().toIso8601String();

      // Update member last_read_at.
      await _client.from('chat_members').upsert(<String, dynamic>{
        'chat_id': chatId,
        'user_id': uid,
        'last_read_at': now,
      }, onConflict: 'chat_id,user_id');

      // Reset unread count via RPC.
      await _client.rpc('reset_unread_count', params: <String, dynamic>{
        'p_chat_id': chatId,
        'p_user_id': uid,
      });

      // Mark incoming messages as read in the background.
      _markIncomingAsRead(chatId, uid);

      return const ChatSuccess<void>(null);
    } on sb.PostgrestException catch (e) {
      if (e.code == '42501') return const ChatFailedResult(PermissionDeniedFailure());
      return ChatFailedResult(MessageSendFailure(e.message));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  // ── streamTotalUnreadCount ─────────────────────────────────────────────────

  @override
  Stream<int> streamTotalUnreadCount() {
    return streamChats().map((chats) {
      final uid = _currentUid;
      if (uid == null) return 0;
      return chats.fold<int>(0, (total, chat) {
        return total + (chat.unreadCounts[uid] ?? 0);
      });
    });
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  void _markDelivered(
      String chatId, List<Message> messages, String currentUid) {
    final toUpdate = messages
        .where((m) =>
            m.senderId != currentUid && m.status == MessageStatus.sent)
        .map((m) => m.id)
        .toList();

    if (toUpdate.isEmpty) return;

    _client
        .from('messages')
        .update(<String, dynamic>{'status': MessageStatus.delivered.name})
        .inFilter('id', toUpdate)
        .then((_) {})
        .catchError((Object e) {
      debugPrint('[SupabaseChatRepository] mark delivered error: $e');
    });
  }

  Future<void> _markIncomingAsRead(String chatId, String currentUid) async {
    try {
      await _client
          .from('messages')
          .update(<String, dynamic>{'status': MessageStatus.read.name})
          .eq('chat_id', chatId)
          .neq('sender_id', currentUid)
          .neq('status', MessageStatus.read.name);
    } catch (e) {
      debugPrint('[SupabaseChatRepository] mark read error: $e');
    }
  }

  Chat _chatFromRow(Map<String, dynamic> row) {
    final participants = (row['participants'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => e as String)
        .toList();

    final unreadRaw =
        row['unread_counts'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final unreadCounts = unreadRaw.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    return Chat(
      id: row['id'] as String,
      title: row['title'] as String?,
      isGroup: row['is_group'] as bool? ?? false,
      participants: participants,
      lastMessageText: row['last_message_text'] as String? ?? '',
      lastMessageSenderId: row['last_message_sender_id'] as String? ?? '',
      lastMessageTime: _parseDateTime(row['last_message_time']),
      updatedAt: _parseDateTime(row['updated_at']),
      unreadCounts: unreadCounts,
    );
  }

  Message _messageFromRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String? ?? '',
      content: row['content'] as String,
      createdAt: _parseDateTime(row['created_at']),
      editedAt: row['edited_at'] != null
          ? _parseDateTime(row['edited_at'])
          : null,
      status: MessageStatus.values.firstWhere(
        (s) => s.name == (row['status'] as String? ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc() ??
        DateTime.now().toUtc();
  }
}
