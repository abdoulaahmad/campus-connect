import 'dart:async';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../datasources/local_message_datasource.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/sync_command.dart';

class OfflineChatRepository implements IChatRepository {
  OfflineChatRepository({
    required this.inner,
    required this.localDatasource,
    required this.connectivity,
    required this.getCurrentUserId,
  });

  final IChatRepository inner;
  final LocalMessageDatasource localDatasource;
  final ConnectivityService connectivity;
  final Future<String?> Function() getCurrentUserId;

  @override
  Stream<List<Chat>> streamChats() {
    final controller = StreamController<List<Chat>>.broadcast();
    StreamSubscription? innerSub;
    StreamSubscription? connSub;

    void startOnlineStream() {
      innerSub?.cancel();
      innerSub = inner.streamChats().listen(
        (chats) async {
          await localDatasource.cacheChats(chats);
          if (!controller.isClosed) {
            controller.add(chats);
          }
        },
        onError: (err) async {
          if (!controller.isClosed) {
            final cached = await localDatasource.getCachedChats();
            if (!controller.isClosed) controller.add(cached);
          }
        },
      );
    }

    void startOfflineStream() async {
      innerSub?.cancel();
      final cached = await localDatasource.getCachedChats();
      if (!controller.isClosed) {
        controller.add(cached);
      }
    }

    // Monitor connectivity transitions
    connSub = connectivity.isOnline$.listen((isOnline) {
      if (isOnline) {
        startOnlineStream();
      } else {
        startOfflineStream();
      }
    });

    // Seed initial cache immediately
    localDatasource.getCachedChats().then((cached) {
      if (!controller.isClosed && cached.isNotEmpty) {
        controller.add(cached);
      }
    });

    controller.onCancel = () {
      innerSub?.cancel();
      connSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<Message>> streamMessages(String chatId) {
    final controller = StreamController<List<Message>>.broadcast();
    StreamSubscription? innerSub;
    StreamSubscription? connSub;

    void startOnlineStream() {
      innerSub?.cancel();
      innerSub = inner.streamMessages(chatId).listen(
        (messages) async {
          await localDatasource.cacheMessages(chatId, messages);
          if (!controller.isClosed) {
            controller.add(messages);
          }
        },
        onError: (err) async {
          if (!controller.isClosed) {
            final cached = await localDatasource.getCachedMessages(chatId);
            if (!controller.isClosed) controller.add(cached);
          }
        },
      );
    }

    void startOfflineStream() async {
      innerSub?.cancel();
      final cached = await localDatasource.getCachedMessages(chatId);
      if (!controller.isClosed) {
        controller.add(cached);
      }
    }

    connSub = connectivity.isOnline$.listen((isOnline) {
      if (isOnline) {
        startOnlineStream();
      } else {
        startOfflineStream();
      }
    });

    localDatasource.getCachedMessages(chatId).then((cached) {
      if (!controller.isClosed && cached.isNotEmpty) {
        controller.add(cached);
      }
    });

    controller.onCancel = () {
      innerSub?.cancel();
      connSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<ChatResult<void>> sendMessage(String chatId, Message message) async {
    final isOnline = await connectivity.isOnlineNow;
    if (isOnline) {
      return inner.sendMessage(chatId, message);
    }

    // Offline logic
    try {
      // 1. Cache the local message draft immediately with 'sending' status
      final localMsg = message.copyWith(status: MessageStatus.sending);
      await localDatasource.cacheMessages(chatId, [localMsg]);

      // 2. Update chat preview meta in cached chats
      final cachedChats = await localDatasource.getCachedChats();
      final chatIndex = cachedChats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
        final chat = cachedChats[chatIndex];
        final updatedChat = chat.copyWith(
          lastMessageText: message.content,
          lastMessageSenderId: message.senderId,
          lastMessageTime: message.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
        cachedChats[chatIndex] = updatedChat;
        await localDatasource.cacheChats(cachedChats);
      }

      // 3. Enqueue the send command
      final cmd = SyncCommand(
        commandType: 'sendMessage',
        chatId: chatId,
        messageId: message.id,
        payload: {
          'id': message.id,
          'senderId': message.senderId,
          'senderName': message.senderName,
          'content': message.content,
          'createdAt': message.createdAt.toUtc().toIso8601String(),
        },
        createdAt: DateTime.now().toUtc(),
      );
      await localDatasource.enqueueCommand(cmd);

      return const ChatSuccess<void>(null);
    } catch (e) {
      return ChatFailedResult(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> editMessage(String chatId, String messageId, String newContent) async {
    final isOnline = await connectivity.isOnlineNow;
    if (isOnline) {
      return inner.editMessage(chatId, messageId, newContent);
    }

    // Offline logic
    try {
      // Retrieve the message to check 120s window constraint
      final cachedMessages = await localDatasource.getCachedMessages(chatId);
      final msgIndex = cachedMessages.indexWhere((m) => m.id == messageId);
      if (msgIndex == -1) {
        return const ChatFailedResult(LocalStorageFailure('Message not found locally.'));
      }

      final msg = cachedMessages[msgIndex];
      // Enforce the 120-second edit window rule
      if (!msg.isEditable) {
        return const ChatFailedResult(MessageEditExpiredFailure());
      }

      // 1. Update message content and edited_at timestamp in local database
      final updatedMsg = msg.copyWith(
        content: newContent,
        editedAt: DateTime.now().toUtc(),
      );
      await localDatasource.cacheMessages(chatId, [updatedMsg]);

      // 2. Update parent chat preview if this is the last message
      final cachedChats = await localDatasource.getCachedChats();
      final chatIndex = cachedChats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
        final chat = cachedChats[chatIndex];
        if (chat.lastMessageTime != null && chat.lastMessageTime!.isAtSameMomentAs(msg.createdAt)) {
          final updatedChat = chat.copyWith(
            lastMessageText: newContent,
            updatedAt: DateTime.now().toUtc(),
          );
          cachedChats[chatIndex] = updatedChat;
          await localDatasource.cacheChats(cachedChats);
        }
      }

      // 3. Enqueue command
      final cmd = SyncCommand(
        commandType: 'editMessage',
        chatId: chatId,
        messageId: messageId,
        payload: {
          'messageId': messageId,
          'newContent': newContent,
        },
        createdAt: DateTime.now().toUtc(),
      );
      await localDatasource.enqueueCommand(cmd);

      return const ChatSuccess<void>(null);
    } catch (e) {
      return ChatFailedResult(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> markAsRead(String chatId) async {
    final isOnline = await connectivity.isOnlineNow;
    if (isOnline) {
      return inner.markAsRead(chatId);
    }

    // Offline logic
    try {
      // 1. Clear unread badge locally
      final currentUid = await getCurrentUserId();
      if (currentUid != null) {
        final cachedChats = await localDatasource.getCachedChats();
        final chatIndex = cachedChats.indexWhere((c) => c.id == chatId);
        if (chatIndex != -1) {
          final chat = cachedChats[chatIndex];
          final updatedUnread = Map<String, int>.from(chat.unreadCounts);
          updatedUnread[currentUid] = 0;
          
          final updatedChat = chat.copyWith(unreadCounts: updatedUnread);
          cachedChats[chatIndex] = updatedChat;
          await localDatasource.cacheChats(cachedChats);
        }
      }

      // 2. Mark local messages as read
      final cachedMessages = await localDatasource.getCachedMessages(chatId);
      final currentUserIdValue = await getCurrentUserId();
      bool modified = false;
      for (int i = 0; i < cachedMessages.length; i++) {
        final msg = cachedMessages[i];
        if (msg.senderId != currentUserIdValue && msg.status != MessageStatus.read) {
          cachedMessages[i] = msg.copyWith(status: MessageStatus.read);
          modified = true;
        }
      }
      if (modified) {
        await localDatasource.cacheMessages(chatId, cachedMessages);
      }

      // 3. Enqueue command
      final cmd = SyncCommand(
        commandType: 'markAsRead',
        chatId: chatId,
        payload: {},
        createdAt: DateTime.now().toUtc(),
      );
      await localDatasource.enqueueCommand(cmd);

      return const ChatSuccess<void>(null);
    } catch (e) {
      return ChatFailedResult(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> setTyping(String chatId, bool isTyping) async {
    final isOnline = await connectivity.isOnlineNow;
    if (isOnline) {
      return inner.setTyping(chatId, isTyping);
    }
    return const ChatSuccess<void>(null);
  }

  @override
  Stream<List<String>> streamTypingUsers(String chatId) {
    final controller = StreamController<List<String>>.broadcast();
    StreamSubscription? connSub;
    StreamSubscription? innerSub;

    void startOnlineStream() {
      innerSub?.cancel();
      innerSub = inner.streamTypingUsers(chatId).listen(
        (typers) {
          if (!controller.isClosed) controller.add(typers);
        },
        onError: (_) {
          if (!controller.isClosed) controller.add(<String>[]);
        },
      );
    }

    void startOfflineStream() {
      innerSub?.cancel();
      if (!controller.isClosed) controller.add(<String>[]);
    }

    connSub = connectivity.isOnline$.listen((isOnline) {
      if (isOnline) {
        startOnlineStream();
      } else {
        startOfflineStream();
      }
    });

    controller.onCancel = () {
      innerSub?.cancel();
      connSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<int> streamTotalUnreadCount() {
    final controller = StreamController<int>.broadcast();
    StreamSubscription? innerSub;
    StreamSubscription? connSub;
    StreamSubscription? chatSub;

    void startOnlineStream() {
      chatSub?.cancel();
      innerSub?.cancel();
      innerSub = inner.streamTotalUnreadCount().listen(
        (count) {
          if (!controller.isClosed) controller.add(count);
        },
        onError: (_) {},
      );
    }

    void startOfflineStream() {
      innerSub?.cancel();
      chatSub = streamChats().listen((chats) async {
        final currentUid = await getCurrentUserId();
        if (currentUid == null) {
          if (!controller.isClosed) controller.add(0);
          return;
        }
        int total = 0;
        for (final chat in chats) {
          total += chat.unreadCounts[currentUid] ?? 0;
        }
        if (!controller.isClosed) controller.add(total);
      });
    }

    connSub = connectivity.isOnline$.listen((isOnline) {
      if (isOnline) {
        startOnlineStream();
      } else {
        startOfflineStream();
      }
    });

    controller.onCancel = () {
      innerSub?.cancel();
      connSub?.cancel();
      chatSub?.cancel();
    };

    return controller.stream;
  }
}
