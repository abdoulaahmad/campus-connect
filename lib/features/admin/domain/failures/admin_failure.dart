import 'package:meta/meta.dart';

@immutable
sealed class AdminFailure {
  final String message;
  const AdminFailure(this.message);

  @override
  String toString() => message;
}

class AdminOperationFailed extends AdminFailure {
  const AdminOperationFailed([super.message = 'Administrative action failed']);
}

sealed class AdminResult<T> {
  const AdminResult();
}

final class AdminSuccess<T> extends AdminResult<T> {
  final T value;
  const AdminSuccess(this.value);
}

final class AdminFailed<T> extends AdminResult<T> {
  final AdminFailure failure;
  const AdminFailed(this.failure);
}
