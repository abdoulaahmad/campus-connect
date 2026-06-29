import '../entities/chat.dart';
import '../entities/message.dart';
import '../failures/chat_failure.dart';

/// Abstract contract defining all messaging data operations.
///
/// Implemented across three concrete repositories:
/// - [FirestoreChatRepository] (production)
/// - [MockoonChatRepository] (development HTTP polling)
/// - [MockChatRepository] (in-memory testing)
abstract class IChatRepository {
  /// Stream a list of all conversations the current user is a member of.
  Stream<List<Chat>> streamChats();

  /// Stream messages for a specific conversation room (ordered chronologically ASC).
  Stream<List<Message>> streamMessages(String chatId);

  /// Writes a message to the database (transitions state from `sending` to `sent`).
  Future<ChatResult<void>> sendMessage(String chatId, Message message);

  /// Replaces message content in the database and sets the `editedAt` field.
  ///
  /// Rejects updates if the 120-second edit window has expired.
  Future<ChatResult<void>> editMessage(String chatId, String messageId, String newContent);

  /// Sets the typing state of the current user inside a specific conversation room.
  Future<ChatResult<void>> setTyping(String chatId, bool isTyping);

  /// Stream list of user IDs currently typing in a conversation room.
  Stream<List<String>> streamTypingUsers(String chatId);

  /// Marks the conversation as read by the current user.
  ///
  /// Updates the member's `last_read_at` timestamp and recalculates unread metrics.
  Future<ChatResult<void>> markAsRead(String chatId);

  /// Stream of total unread messages count across all conversations.
  Stream<int> streamTotalUnreadCount();
}
