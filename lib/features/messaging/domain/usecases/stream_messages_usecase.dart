import '../entities/message.dart';
import '../repositories/i_chat_repository.dart';

/// Use case to stream messages in a specific chat room.
class StreamMessagesUseCase {
  const StreamMessagesUseCase(this._repository);

  final IChatRepository _repository;

  Stream<List<Message>> call(String chatId) {
    return _repository.streamMessages(chatId);
  }
}
