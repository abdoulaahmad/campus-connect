import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/failures/chat_failure.dart';
import '../../domain/usecases/edit_message_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/stream_chats_usecase.dart';
import '../../domain/usecases/stream_messages_usecase.dart';

// ── Stream Providers ────────────────────────────────────────────────────────

/// Stream provider exposing the list of conversations the user belongs to.
final chatsStreamProvider = StreamProvider<List<Chat>>((Ref ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return StreamChatsUseCase(repo).call();
});

/// Family stream provider exposing messages for a specific conversation room.
final chatRoomMessagesProvider = StreamProvider.family<List<Message>, String>((Ref ref, String chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return StreamMessagesUseCase(repo).call(chatId);
});

/// Family stream provider exposing the list of user IDs currently typing in a chat room.
final chatRoomTypingUsersProvider = StreamProvider.family<List<String>, String>((Ref ref, String chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.streamTypingUsers(chatId);
});

/// Stream provider exposing the total count of unread messages across all chats.
final totalUnreadCountProvider = StreamProvider<int>((Ref ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.streamTotalUnreadCount();
});

// ── Mutation Actions Provider ──────────────────────────────────────────────

/// Helper class coordinating chat room mutations and operations.
class ChatActions {
  const ChatActions(this._ref);

  final Ref _ref;

  /// Creates and sends a message to the specified conversation room.
  ///
  /// Instantiates a new [Message] with `sending` status, then delegates
  /// to the [SendMessageUseCase] which writes it to the repository.
  Future<ChatResult<void>> sendMessage({
    required String chatId,
    required String content,
  }) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthAuthenticated) {
      return const ChatFailedResult(PermissionDeniedFailure());
    }

    final user = authState.user;
    final message = Message(
      id: 'msg_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      senderId: user.id,
      senderName: user.name,
      content: content,
      createdAt: DateTime.now().toUtc(),
      status: MessageStatus.sending, // Initial client state is sending
    );

    final useCase = SendMessageUseCase(_ref.read(chatRepositoryProvider));
    try {
      await useCase.call(chatId: chatId, message: message);
      return const ChatSuccess<void>(null);
    } on ChatFailure catch (e) {
      return ChatFailedResult(e);
    } catch (e) {
      return ChatFailedResult(MessageSendFailure(e.toString()));
    }
  }

  /// Updates an existing message's text.
  ///
  /// Delegates to [EditMessageUseCase] which verifies the 120-second edit window.
  Future<ChatResult<void>> editMessage({
    required String chatId,
    required Message message,
    required String newContent,
  }) async {
    final useCase = EditMessageUseCase(_ref.read(chatRepositoryProvider));
    return useCase.call(chatId: chatId, message: message, newContent: newContent);
  }

  /// Sets the active user's typing status inside a conversation.
  Future<ChatResult<void>> setTyping({
    required String chatId,
    required bool isTyping,
  }) async {
    return _ref.read(chatRepositoryProvider).setTyping(chatId, isTyping);
  }

  /// Updates the user's read receipt and clears their unread counts.
  Future<ChatResult<void>> markAsRead({
    required String chatId,
  }) async {
    return _ref.read(chatRepositoryProvider).markAsRead(chatId);
  }
}

/// Provider exposing [ChatActions] instance for UI components.
final chatActionsProvider = Provider<ChatActions>((Ref ref) {
  return ChatActions(ref);
});
