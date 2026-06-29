import 'package:meta/meta.dart';

@immutable
sealed class ScheduleFailure {
  final String message;
  const ScheduleFailure(this.message);

  @override
  String toString() => message;
}

class InvalidBitmaskFailure extends ScheduleFailure {
  const InvalidBitmaskFailure([super.message = 'Invalid bitmask sequence. Must be 48 bits of 0s and 1s.']);
}

class ScheduleStorageFailure extends ScheduleFailure {
  const ScheduleStorageFailure([super.message = 'Failed to load/save availability schedule']);
}

class ScheduleUnknownFailure extends ScheduleFailure {
  const ScheduleUnknownFailure([super.message = 'An unknown schedule error occurred']);
}

sealed class ScheduleResult<T> {
  const ScheduleResult();
}

final class ScheduleSuccess<T> extends ScheduleResult<T> {
  final T value;
  const ScheduleSuccess(this.value);
}

final class ScheduleFailed<T> extends ScheduleResult<T> {
  final ScheduleFailure failure;
  const ScheduleFailed(this.failure);
}
