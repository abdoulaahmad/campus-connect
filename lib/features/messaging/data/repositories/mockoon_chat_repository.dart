import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Development environment Mockoon API repository implementation of [IChatRepository].
///
/// Simulates real-time streams via periodic REST polling using [Dio].
class MockoonChatRepository implements IChatRepository {
  MockoonChatRepository({
    required Dio dio,
    required SecureStorageService storage,
  })  : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final SecureStorageService _storage;

  Future<String> _getCurrentUid() async {
    return (await _storage.getLastUserId()) ?? 'dev_user_id';
  }

  ChatFailure _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkFailure();
    }
    if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
      return const PermissionDeniedFailure();
    }
    return MessageSendFailure(e.message ?? 'Server connection error.');
  }

  @override
  Stream<List<Chat>> streamChats() {
    // Poll the backend every 3 seconds to simulate updates
    final controller = StreamController<List<Chat>>.broadcast();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final uid = await _getCurrentUid();
        final response = await _dio.get<List<dynamic>>('/chats', queryParameters: <String, dynamic>{
          'user_id': uid,
        });

        if (response.data != null) {
          final chats = response.data!.map((dynamic item) {
            return ChatModel.fromMap(
              (item as Map<String, dynamic>)['id']?.toString() ?? '',
              item,
            );
          }).toList();
          if (!controller.isClosed) {
            controller.add(chats);
          }
        }
      } catch (e) {
        // Suppress print crash and emit empty array or cached values on disconnect
        if (!controller.isClosed) {
          controller.add(<Chat>[]);
        }
      }
    }

    // Initial fetch
    fetch();

    timer = Timer.periodic(const Duration(seconds: 3), (_) => fetch());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<List<Message>> streamMessages(String chatId) {
    final controller = StreamController<List<Message>>.broadcast();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final response = await _dio.get<List<dynamic>>('/chats/$chatId/messages');

        if (response.data != null) {
          final messages = response.data!.map((dynamic item) {
            return MessageModel.fromMap(
              (item as Map<String, dynamic>)['id']?.toString() ?? '',
              item,
            );
          }).toList();
          if (!controller.isClosed) {
            controller.add(messages);
          }
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(<Message>[]);
        }
      }
    }

    fetch();

    timer = Timer.periodic(const Duration(seconds: 3), (_) => fetch());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<ChatResult<void>> sendMessage(String chatId, Message message) async {
    try {
      final uid = await _getCurrentUid();
      final model = MessageModel(
        id: message.id,
        senderId: uid,
        senderName: message.senderName,
        content: message.content,
        createdAt: message.createdAt,
        status: MessageStatus.sent,
      );

      await _dio.post<dynamic>(
        '/chats/$chatId/messages',
        data: model.toMap(),
      );

      return const ChatSuccess<void>(null);
    } on DioException catch (e) {
      return ChatFailedResult(_handleDioError(e));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> editMessage(String chatId, String messageId, String newContent) async {
    try {
      await _dio.patch<dynamic>(
        '/chats/$chatId/messages/$messageId',
        data: <String, dynamic>{
          'content': newContent,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      return const ChatSuccess<void>(null);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data != null &&
          e.response!.data.toString().contains('window expired')) {
        return const ChatFailedResult(MessageEditExpiredFailure());
      }
      return ChatFailedResult(_handleDioError(e));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Future<ChatResult<void>> setTyping(String chatId, bool isTyping) async {
    try {
      final uid = await _getCurrentUid();
      await _dio.post<dynamic>(
        '/chats/$chatId/typing',
        data: <String, dynamic>{
          'user_id': uid,
          'is_typing': isTyping,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      return const ChatSuccess<void>(null);
    } on DioException catch (e) {
      return ChatFailedResult(_handleDioError(e));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Stream<List<String>> streamTypingUsers(String chatId) {
    final controller = StreamController<List<String>>.broadcast();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final response = await _dio.get<List<dynamic>>('/chats/$chatId/typing');

        if (response.data != null) {
          final list = response.data!
              .map((dynamic item) => (item as Map<String, dynamic>)['user_id']?.toString() ?? '')
              .where((String uid) => uid.isNotEmpty)
              .toList();
          if (!controller.isClosed) {
            controller.add(list);
          }
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(<String>[]);
        }
      }
    }

    fetch();

    timer = Timer.periodic(const Duration(seconds: 3), (_) => fetch());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<ChatResult<void>> markAsRead(String chatId) async {
    try {
      final uid = await _getCurrentUid();
      await _dio.post<dynamic>(
        '/chats/$chatId/read',
        data: <String, dynamic>{
          'user_id': uid,
        },
      );

      return const ChatSuccess<void>(null);
    } on DioException catch (e) {
      return ChatFailedResult(_handleDioError(e));
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  @override
  Stream<int> streamTotalUnreadCount() {
    final controller = StreamController<int>.broadcast();
    Timer? timer;

    Future<void> fetch() async {
      try {
        final uid = await _getCurrentUid();
        final response = await _dio.get<Map<String, dynamic>>('/chats/unread', queryParameters: <String, dynamic>{
          'user_id': uid,
        });

        if (response.data != null) {
          final count = int.tryParse(response.data!['unread_count']?.toString() ?? '0') ?? 0;
          if (!controller.isClosed) {
            controller.add(count);
          }
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(0);
        }
      }
    }

    fetch();

    timer = Timer.periodic(const Duration(seconds: 3), (_) => fetch());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
