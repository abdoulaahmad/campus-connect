import '../entities/chat.dart';
import '../repositories/i_chat_repository.dart';

/// Use case to stream conversations the current user participates in.
class StreamChatsUseCase {
  const StreamChatsUseCase(this._repository);

  final IChatRepository _repository;

  Stream<List<Chat>> call() {
    return _repository.streamChats();
  }
}
