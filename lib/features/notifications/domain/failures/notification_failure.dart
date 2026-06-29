import 'package:meta/meta.dart';

@immutable
sealed class NotificationFailure {
  final String message;
  const NotificationFailure(this.message);

  @override
  String toString() => message;
}

class NotificationStorageFailure extends NotificationFailure {
  const NotificationStorageFailure([super.message = 'Failed to load/save notification history']);
}

sealed class NotificationResult<T> {
  const NotificationResult();
}

final class NotificationSuccess<T> extends NotificationResult<T> {
  final T value;
  const NotificationSuccess(this.value);
}

final class NotificationFailed<T> extends NotificationResult<T> {
  final NotificationFailure failure;
  const NotificationFailed(this.failure);
}
