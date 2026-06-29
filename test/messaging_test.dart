import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/features/messaging/domain/entities/message.dart';
import 'package:campus_connect/features/messaging/domain/entities/chat.dart';
import 'package:campus_connect/features/messaging/domain/failures/chat_failure.dart';
import 'package:campus_connect/features/messaging/domain/usecases/edit_message_usecase.dart';
import 'package:campus_connect/features/messaging/data/repositories/mock_chat_repository.dart';
import 'package:campus_connect/core/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:campus_connect/core/services/connectivity_service.dart';
import 'package:campus_connect/core/database/app_database.dart';
import 'package:campus_connect/features/messaging/data/datasources/local_message_datasource.dart';
import 'package:campus_connect/features/messaging/data/models/sync_command.dart';
import 'package:campus_connect/features/messaging/data/repositories/offline_chat_repository.dart';
import 'package:campus_connect/features/messaging/data/services/sync_worker.dart';


// Simple in-memory fake of SecureStorageService to bypass platform channels and custom signatures
class FakeSecureStorageService extends SecureStorageService {
  FakeSecureStorageService() : super.custom(const FlutterSecureStorage());

  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> saveLastUserId(String userId) async {
    _data['last_logged_in_user_id'] = userId;
  }

  @override
  Future<String?> getLastUserId() async {
    return _data['last_logged_in_user_id'];
  }

  @override
  Future<void> clearSession() async {
    _data.clear();
  }
}

void main() {
  group('Messaging Domain & UseCase Tests', () {
    test('120-second message edit constraint check', () {
      final now = DateTime.now().toUtc();

      final editableMsg = Message(
        id: 'msg_new',
        senderId: 'sender_1',
        senderName: 'Sender One',
        content: 'I am editable',
        createdAt: now.subtract(const Duration(seconds: 30)),
        status: MessageStatus.sent,
      );

      final expiredMsg = Message(
        id: 'msg_old',
        senderId: 'sender_1',
        senderName: 'Sender One',
        content: 'Time expired',
        createdAt: now.subtract(const Duration(seconds: 125)),
        status: MessageStatus.sent,
      );

      expect(editableMsg.isEditable, isTrue);
      expect(expiredMsg.isEditable, isFalse);
    });

    test('EditMessageUseCase blocks editing after 120 seconds', () async {
      final secureStorage = FakeSecureStorageService();
      final repo = MockChatRepository(storage: secureStorage);
      final useCase = EditMessageUseCase(repo);

      final now = DateTime.now().toUtc();
      final expiredMsg = Message(
        id: 'msg_d2', // From pre-seeded direct chat mock messages
        senderId: 'john_uid',
        senderName: 'John Doe',
        content: 'I have some materials to share.',
        createdAt: now.subtract(const Duration(seconds: 130)),
        status: MessageStatus.sent,
      );

      final result = await useCase.call(
        chatId: 'chat_direct_1',
        message: expiredMsg,
        newContent: 'Attempted edit text',
      );

      expect(result, isA<ChatFailedResult<void>>());
      final failure = (result as ChatFailedResult<void>).failure;
      expect(failure, isA<MessageEditExpiredFailure>());
    });
  });

  group('MockChatRepository Stream & Status Tests', () {
    late FakeSecureStorageService secureStorage;
    late MockChatRepository repository;

    setUp(() async {
      secureStorage = FakeSecureStorageService();
      await secureStorage.saveLastUserId('test_user_id');
      repository = MockChatRepository(storage: secureStorage);
    });

    test('Sending a message adds to stream and triggers correct status transitions', () async {
      final message = Message(
        id: 'new_temp_id',
        senderId: 'test_user_id',
        senderName: 'Test Student',
        content: 'Unit Testing message send',
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.sending, // Starts as sending
      );

      // Verify message list stream updates
      final streamFuture = repository.streamMessages('chat_direct_1').first;
      
      final sendResult = await repository.sendMessage('chat_direct_1', message);
      expect(sendResult, isA<ChatSuccess<void>>());

      final messages = await streamFuture;
      
      // The sent message is present in the list, and its database status is 'sent'
      final dbMsg = messages.firstWhere((m) => m.id == 'new_temp_id');
      expect(dbMsg.status, equals(MessageStatus.sent));
      expect(dbMsg.content, equals('Unit Testing message send'));
    });

    test('Reading a chat marks all incoming messages as read and updates unread badge count', () async {
      // 1. Initial unread check
      final initialUnread = await repository.streamTotalUnreadCount().first;
      expect(initialUnread, equals(2)); // Pre-seeded unread messages

      // 2. Mark chat as read
      final markReadResult = await repository.markAsRead('chat_direct_1');
      expect(markReadResult, isA<ChatSuccess<void>>());

      // 3. Verify unread count becomes 0
      final updatedUnread = await repository.streamTotalUnreadCount().first;
      expect(updatedUnread, equals(0));

      // 4. Verify message statuses in stream changed to read
      final messages = await repository.streamMessages('chat_direct_1').first;
      for (final msg in messages) {
        if (msg.senderId != 'test_user_id') {
          expect(msg.status, equals(MessageStatus.read));
        }
      }
    });
  });

  group('OfflineChatRepository & Sync Queue Tests', () {
    late FakeSecureStorageService secureStorage;
    late MockChatRepository mockInnerRepo;
    late FakeLocalMessageDatasource fakeLocalDb;
    late ConnectivityService connectivity;
    late OfflineChatRepository offlineRepo;

    setUp(() async {
      secureStorage = FakeSecureStorageService();
      await secureStorage.saveLastUserId('test_user_id');
      mockInnerRepo = MockChatRepository(storage: secureStorage);
      fakeLocalDb = FakeLocalMessageDatasource();
      connectivity = const ConnectivityService();
      
      offlineRepo = OfflineChatRepository(
        inner: mockInnerRepo,
        localDatasource: fakeLocalDb,
        connectivity: connectivity,
        getCurrentUserId: () async => 'test_user_id',
      );

      ConnectivityService.setMockOnline(null); // Reset
    });

    test('sendMessage while offline enqueues command and returns ChatSuccess', () async {
      // 1. Go offline
      ConnectivityService.setMockOnline(false);

      final message = Message(
        id: 'offline_msg_1',
        senderId: 'test_user_id',
        senderName: 'Test Student',
        content: 'Send this when online',
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.sending,
      );

      final result = await offlineRepo.sendMessage('chat_direct_1', message);
      expect(result, isA<ChatSuccess<void>>());

      // Verify enqueued in queue
      final pending = await fakeLocalDb.getPendingCommands();
      expect(pending.length, equals(1));
      expect(pending.first.commandType, equals('sendMessage'));
      expect(pending.first.payload['content'], equals('Send this when online'));

      // Verify saved in local cache as sending
      final cached = await fakeLocalDb.getCachedMessages('chat_direct_1');
      expect(cached.length, equals(1));
      expect(cached.first.status, equals(MessageStatus.sending));
    });

    test('editMessage while offline respects 120s window', () async {
      ConnectivityService.setMockOnline(false);

      final now = DateTime.now().toUtc();
      
      // Cache messages
      final msgOld = Message(
        id: 'msg_old',
        senderId: 'test_user_id',
        senderName: 'Test Student',
        content: 'Old content',
        createdAt: now.subtract(const Duration(seconds: 130)),
        status: MessageStatus.sent,
      );

      final msgNew = Message(
        id: 'msg_new',
        senderId: 'test_user_id',
        senderName: 'Test Student',
        content: 'New content',
        createdAt: now.subtract(const Duration(seconds: 30)),
        status: MessageStatus.sent,
      );

      await fakeLocalDb.cacheMessages('chat_direct_1', [msgOld, msgNew]);

      // Edit old message -> Should fail
      final resultOld = await offlineRepo.editMessage('chat_direct_1', 'msg_old', 'Edited Old');
      expect(resultOld, isA<ChatFailedResult<void>>());
      expect((resultOld as ChatFailedResult<void>).failure, isA<MessageEditExpiredFailure>());

      // Edit new message -> Should succeed
      final resultNew = await offlineRepo.editMessage('chat_direct_1', 'msg_new', 'Edited New');
      expect(resultNew, isA<ChatSuccess<void>>());

      // Verify command enqueued
      final pending = await fakeLocalDb.getPendingCommands();
      expect(pending.length, equals(1));
      expect(pending.first.commandType, equals('editMessage'));
      expect(pending.first.payload['newContent'], equals('Edited New'));
    });

    test('syncWorker replays queue on reconnect', () async {
      ConnectivityService.setMockOnline(false);

      final message = Message(
        id: 'offline_msg_2',
        senderId: 'test_user_id',
        senderName: 'Test Student',
        content: 'Pending sync message',
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.sending,
      );

      await offlineRepo.sendMessage('chat_direct_1', message);

      // Verify queued
      expect((await fakeLocalDb.getPendingCommands()).length, equals(1));

      // Set up SyncWorker
      final syncWorker = SyncWorker(
        inner: mockInnerRepo,
        localDatasource: fakeLocalDb,
        connectivity: connectivity,
      );

      // Reconnect
      ConnectivityService.setMockOnline(true);

      // Wait a brief moment for worker to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify queue cleared
      final pendingAfter = await fakeLocalDb.getPendingCommands();
      expect(pendingAfter.isEmpty, isTrue);

      // Verify message sent to repository
      final innerMsgs = await mockInnerRepo.streamMessages('chat_direct_1').first;
      expect(innerMsgs.any((m) => m.id == 'offline_msg_2'), isTrue);

      syncWorker.dispose();
    });

    test('syncWorker increments attempt and removes after 3 failures', () async {
      ConnectivityService.setMockOnline(false);

      final cmd = SyncCommand(
        commandType: 'sendMessage',
        chatId: 'chat_direct_invalid', // Will cause inner mock repo to fail since chat doesn't exist
        messageId: 'fail_msg_1',
        payload: {
          'id': 'fail_msg_1',
          'senderId': 'test_user_id',
          'senderName': 'Test Student',
          'content': 'Failing msg',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        createdAt: DateTime.now().toUtc(),
      );

      await fakeLocalDb.enqueueCommand(cmd);

      final failingRepo = TransientFailureChatRepository(storage: secureStorage);
      final syncWorker = SyncWorker(
        inner: failingRepo,
        localDatasource: fakeLocalDb,
        connectivity: connectivity,
      );

      // Trigger sync by going online
      ConnectivityService.setMockOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Attempt 1 fails, retry count is 1
      var pending = await fakeLocalDb.getPendingCommands();
      expect(pending.length, equals(1));
      expect(pending.first.attemptCount, equals(1));

      // Trigger sync again
      ConnectivityService.setMockOnline(false);
      ConnectivityService.setMockOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Attempt 2 fails, retry count is 2
      pending = await fakeLocalDb.getPendingCommands();
      expect(pending.length, equals(1));
      expect(pending.first.attemptCount, equals(2));

      // Trigger sync again -> Should drop command (attempt count reaches 3, which is idx >= 2)
      ConnectivityService.setMockOnline(false);
      ConnectivityService.setMockOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Dropped from queue
      pending = await fakeLocalDb.getPendingCommands();
      expect(pending.isEmpty, isTrue);

      syncWorker.dispose();
    });
  });
}

class FakeLocalMessageDatasource extends LocalMessageDatasource {
  FakeLocalMessageDatasource() : super(AppDatabase.instance);

  final List<Chat> _chats = [];
  final List<Message> _messages = [];
  final List<SyncCommand> _commands = [];
  int _nextCommandId = 1;

  @override
  Future<void> cacheChats(List<Chat> chats) async {
    _chats.clear();
    _chats.addAll(chats);
  }

  @override
  Future<List<Chat>> getCachedChats() async {
    return List.from(_chats);
  }

  @override
  Future<void> cacheMessages(String chatId, List<Message> messages) async {
    for (final m in messages) {
      _messages.removeWhere((existing) => existing.id == m.id);
      _messages.add(m);
    }
  }

  @override
  Future<List<Message>> getCachedMessages(String chatId) async {
    return _messages.toList();
  }

  @override
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(status: status);
    }
  }

  @override
  Future<void> enqueueCommand(SyncCommand command) async {
    _commands.add(command.copyWith(id: _nextCommandId++));
  }

  @override
  Future<List<SyncCommand>> getPendingCommands() async {
    return List.from(_commands);
  }

  @override
  Future<void> markCommandSuccess(int id) async {
    _commands.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> incrementCommandAttempt(int id, String error) async {
    final idx = _commands.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final cmd = _commands[idx];
      _commands[idx] = cmd.copyWith(
        attemptCount: cmd.attemptCount + 1,
        lastError: error,
      );
    }
  }

  @override
  Future<void> removeCommand(int id) async {
    _commands.removeWhere((c) => c.id == id);
  }
}

class TransientFailureChatRepository extends MockChatRepository {
  TransientFailureChatRepository({required super.storage});

  @override
  Future<ChatResult<void>> sendMessage(String chatId, Message message) async {
    return const ChatFailedResult(MessageSendFailure('Transient network issue'));
  }
}


