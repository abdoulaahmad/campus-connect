import 'dart:async';
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/repositories/i_chat_repository.dart';

/// Test environment in-memory mock implementation of [IChatRepository].
///
/// Keeps state in-memory and pushes updates to active broadcast streams.
class MockChatRepository implements IChatRepository {
  MockChatRepository({required SecureStorageService storage}) : _storage = storage {
    _initMockData();
  }

  final SecureStorageService _storage;

  // In-memory data store
  final List<Chat> _chats = <Chat>[];
  final Map<String, List<Message>> _messages = <String, List<Message>>{};
  final Map<String, Set<String>> _typingUsers = <String, Set<String>>{};

  // Stream Controllers
  final StreamController<List<Chat>> _chatsController = StreamController<List<Chat>>.broadcast();
  final Map<String, StreamController<List<Message>>> _messagesControllers = <String, StreamController<List<Message>>>{};
  final Map<String, StreamController<List<String>>> _typingControllers = <String, StreamController<List<String>>>{};
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();

  void _initMockData() {
    final now = DateTime.now().toUtc();

    // Pre-seed 2 conversations: Direct Chat & Group Chat
    final c1 = Chat(
      id: 'chat_direct_1',
      title: null,
      isGroup: false,
      updatedAt: now.subtract(const Duration(hours: 1)),
      participants: const <String>['test_user_id', 'john_uid'],
      lastMessageText: 'I have some materials to share.',
      lastMessageSenderId: 'john_uid',
      lastMessageTime: now.subtract(const Duration(minutes: 90)),
      unreadCounts: const <String, int>{'test_user_id': 2, 'john_uid': 0},
    );

    final c2 = Chat(
      id: 'chat_group_1',
      title: 'Group 11 Study Chat',
      isGroup: true,
      updatedAt: now.subtract(const Duration(days: 1)),
      participants: const <String>['test_user_id', 'john_uid', 'admin_uid'],
      lastMessageText: 'Welcome to Group 11 Study Chat!',
      lastMessageSenderId: 'john_uid',
      lastMessageTime: now.subtract(const Duration(days: 1)),
      unreadCounts: const <String, int>{'test_user_id': 0, 'john_uid': 0, 'admin_uid': 0},
    );

    _chats.addAll(<Chat>[c1, c2]);

    _messages['chat_direct_1'] = <Message>[
      Message(
        id: 'msg_d1',
        senderId: 'john_uid',
        senderName: 'John Doe',
        content: 'Hey, are you free for the study group?',
        createdAt: now.subtract(const Duration(hours: 2)),
        status: MessageStatus.read,
      ),
      Message(
        id: 'msg_d2',
        senderId: 'john_uid',
        senderName: 'John Doe',
        content: 'I have some materials to share.',
        createdAt: now.subtract(const Duration(minutes: 90)),
        status: MessageStatus.sent, // Eligible for "delivered" status on stream load
      ),
    ];

    _messages['chat_group_1'] = <Message>[
      Message(
        id: 'msg_g1',
        senderId: 'john_uid',
        senderName: 'John Doe',
        content: 'Welcome to Group 11 Study Chat!',
        createdAt: now.subtract(const Duration(days: 1)),
        status: MessageStatus.read,
      ),
    ];

    _typingUsers['chat_direct_1'] = <String>{};
    _typingUsers['chat_group_1'] = <String>{};
  }

  Future<String> _getCurrentUid() async {
    return (await _storage.getLastUserId()) ?? 'test_user_id';
  }

  void _notifyChats() {
    _chatsController.add(List<Chat>.from(_chats));
    _notifyUnread();
  }

  void _notifyMessages(String chatId) {
    final list = _messages[chatId] ?? <Message>[];
    _messagesControllers[chatId]?.add(List<Message>.from(list));
  }

  void _notifyTyping(String chatId) {
    final list = _typingUsers[chatId]?.toList() ?? <String>[];
    _typingControllers[chatId]?.add(list);
  }

  Future<void> _notifyUnread() async {
    final uid = await _getCurrentUid();
    int total = 0;
    for (final chat in _chats) {
      total += chat.unreadCounts[uid] ?? 0;
    }
    _unreadCountController.add(total);
  }

  @override
  Stream<List<Chat>> streamChats() {
    Timer(const Duration(milliseconds: 100), _notifyChats);
    return _chatsController.stream;
  }

  @override
  Stream<List<Message>> streamMessages(String chatId) {
    final controller = _messagesControllers.putIfAbsent(
      chatId,
      () => StreamController<List<Message>>.broadcast(),
    );

    // Run simulated delivery updates in background
    Timer(const Duration(milliseconds: 100), () async {
      final uid = await _getCurrentUid();
      final list = _messages[chatId] ?? <Message>[];
      bool changed = false;

      for (int i = 0; i < list.length; i++) {
        final msg = list[i];
        if (msg.senderId != uid && msg.status == MessageStatus.sent) {
          list[i] = msg.copyWith(status: MessageStatus.delivered);
          changed = true;
        }
      }

      if (changed) {
        _notifyMessages(chatId);
        _notifyChats();
      } else {
        controller.add(List<Message>.from(list));
      }
    });

    return controller.stream;
  }

  @override
  Future<ChatResult<void>> sendMessage(String chatId, Message message) async {
    final uid = await _getCurrentUid();
    final now = DateTime.now().toUtc();

    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) {
      return const ChatFailedResult(PermissionDeniedFailure());
    }

    final chat = _chats[chatIndex];
    final list = _messages[chatId] ?? <Message>[];

    // Local client created message state is sending. Mock writes to database -> sent
    final dbMessage = Message(
      id: message.id,
      senderId: uid,
      senderName: message.senderName,
      content: message.content,
      createdAt: now,
      status: MessageStatus.sent,
    );

    list.add(dbMessage);
    _messages[chatId] = list;

    // Increment unread count for peer participants
    final updatedUnread = Map<String, int>.from(chat.unreadCounts);
    for (final p in chat.participants) {
      if (p != uid) {
        updatedUnread[p] = (updatedUnread[p] ?? 0) + 1;
      }
    }

    _chats[chatIndex] = chat.copyWith(
      lastMessageText: message.content,
      lastMessageSenderId: uid,
      lastMessageTime: now,
      updatedAt: now,
      unreadCounts: updatedUnread,
    );

    _notifyMessages(chatId);
    _notifyChats();

    return const ChatSuccess<void>(null);
  }

  @override
  Future<ChatResult<void>> editMessage(String chatId, String messageId, String newContent) async {
    final list = _messages[chatId] ?? <Message>[];
    final msgIndex = list.indexWhere((m) => m.id == messageId);

    if (msgIndex == -1) {
      return const ChatFailedResult(MessageSendFailure('Message not found.'));
    }

    final message = list[msgIndex];
    if (!message.isEditable) {
      return const ChatFailedResult(MessageEditExpiredFailure());
    }

    final now = DateTime.now().toUtc();
    list[msgIndex] = message.copyWith(
      content: newContent,
      editedAt: now,
    );

    // Update parent preview text if this was the last message
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      final chat = _chats[chatIndex];
      if (chat.lastMessageTime != null && chat.lastMessageTime!.isAtSameMomentAs(message.createdAt)) {
        _chats[chatIndex] = chat.copyWith(lastMessageText: newContent);
      }
    }

    _notifyMessages(chatId);
    _notifyChats();

    return const ChatSuccess<void>(null);
  }

  @override
  Future<ChatResult<void>> setTyping(String chatId, bool isTyping) async {
    final uid = await _getCurrentUid();
    final typers = _typingUsers.putIfAbsent(chatId, () => <String>{});
    
    if (isTyping) {
      typers.add(uid);
    } else {
      typers.remove(uid);
    }

    _notifyTyping(chatId);
    return const ChatSuccess<void>(null);
  }

  @override
  Stream<List<String>> streamTypingUsers(String chatId) {
    final controller = _typingControllers.putIfAbsent(
      chatId,
      () => StreamController<List<String>>.broadcast(),
    );
    Timer(const Duration(milliseconds: 100), () => _notifyTyping(chatId));
    return controller.stream;
  }

  @override
  Future<ChatResult<void>> markAsRead(String chatId) async {
    final uid = await _getCurrentUid();
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);

    if (chatIndex != -1) {
      final chat = _chats[chatIndex];
      final newUnread = Map<String, int>.from(chat.unreadCounts);
      newUnread[uid] = 0;
      _chats[chatIndex] = chat.copyWith(unreadCounts: newUnread);

      // Update all messages from other users to 'read'
      final list = _messages[chatId] ?? <Message>[];
      for (int i = 0; i < list.length; i++) {
        final msg = list[i];
        if (msg.senderId != uid && msg.status != MessageStatus.read) {
          list[i] = msg.copyWith(status: MessageStatus.read);
        }
      }

      _notifyMessages(chatId);
      _notifyChats();
    }

    return const ChatSuccess<void>(null);
  }

  @override
  Stream<int> streamTotalUnreadCount() {
    Timer(const Duration(milliseconds: 100), _notifyUnread);
    return _unreadCountController.stream;
  }
}
