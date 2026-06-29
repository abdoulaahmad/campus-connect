import '../entities/message.dart';
import '../repositories/i_chat_repository.dart';

/// Use case to write a message to a specific conversation.
class SendMessageUseCase {
  const SendMessageUseCase(this._repository);

  final IChatRepository _repository;

  Future<void> call({required String chatId, required Message message}) async {
    await _repository.sendMessage(chatId, message);
  }
}
