/// Sealed hierarchy representing domain failures for the messaging feature.
///
/// Ensures all errors returned from repositories are typed and documented,
/// preventing UI or use cases from handling generic exceptions.
sealed class ChatFailure {
  const ChatFailure();
}

/// Message editing was attempted after the 120-second edit window expired.
class MessageEditExpiredFailure extends ChatFailure {
  const MessageEditExpiredFailure();

  @override
  String toString() => 'MessageEditExpiredFailure: The 120-second edit window has expired.';
}

/// Message failed to send (e.g. database write failure, invalid format).
class MessageSendFailure extends ChatFailure {
  const MessageSendFailure([this.message]);
  final String? message;

  @override
  String toString() => 'MessageSendFailure: ${message ?? "Failed to send message."}';
}

/// Network-related issues preventing message delivery or synchronization.
class NetworkFailure extends ChatFailure {
  const NetworkFailure();

  @override
  String toString() => 'NetworkFailure: Connection error. Please check your internet connection.';
}

/// Requesting user is not authorized or is not a member of the conversation.
class PermissionDeniedFailure extends ChatFailure {
  const PermissionDeniedFailure();

  @override
  String toString() => 'PermissionDeniedFailure: You do not have permission to access this chat.';
}

/// Command was queued locally because the device is currently offline.
/// Not an error — the UI should show a "queued" indicator.
class MessageQueuedOfflineFailure extends ChatFailure {
  const MessageQueuedOfflineFailure();

  @override
  String toString() => 'MessageQueuedOfflineFailure: The message has been queued offline and will send when a connection is restored.';
}

/// A queued command failed all retry attempts during sync.
class SyncFailedFailure extends ChatFailure {
  const SyncFailedFailure(this.commandType, this.messageId);
  final String commandType; // 'sendMessage' | 'editMessage' | 'markAsRead'
  final String messageId;

  @override
  String toString() => 'SyncFailedFailure: $commandType failed for message $messageId after multiple attempts.';
}

/// Local SQLite read or write operation failed.
class LocalStorageFailure extends ChatFailure {
  const LocalStorageFailure([this.message]);
  final String? message;

  @override
  String toString() => 'LocalStorageFailure: ${message ?? "Failed local database operation."}';
}

// ── Result Type ───────────────────────────────────────────────────────────

/// Discriminated result type for all chat operations.
sealed class ChatResult<T> {
  const ChatResult();
}

/// The chat operation completed successfully. [value] holds the result.
final class ChatSuccess<T> extends ChatResult<T> {
  const ChatSuccess(this.value);

  final T value;
}

/// The chat operation failed. [failure] is a typed [ChatFailure] subtype.
final class ChatFailedResult<T> extends ChatResult<T> {
  const ChatFailedResult(this.failure);

  final ChatFailure failure;
}

