import '../entities/message.dart';
import '../failures/chat_failure.dart';
import '../repositories/i_chat_repository.dart';

/// Use case to edit an existing message.
///
/// Implements client-side checking of the Group 11 120-second edit rule.
class EditMessageUseCase {
  const EditMessageUseCase(this._repository);

  final IChatRepository _repository;

  /// Attempts to edit a message's content.
  ///
  /// Enforces that the message is edited within 120 seconds of its creation time.
  /// If the time window has expired, returns a [ChatFailedResult] containing
  /// [MessageEditExpiredFailure].
  Future<ChatResult<void>> call({
    required String chatId,
    required Message message,
    required String newContent,
  }) async {
    if (!message.isEditable) {
      return const ChatFailedResult(MessageEditExpiredFailure());
    }

    return _repository.editMessage(chatId, message.id, newContent);
  }
}
