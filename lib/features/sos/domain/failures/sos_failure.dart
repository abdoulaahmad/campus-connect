import 'package:meta/meta.dart';

@immutable
sealed class SosFailure {
  final String message;
  const SosFailure(this.message);

  @override
  String toString() => message;
}

class LocationUnavailable extends SosFailure {
  const LocationUnavailable([super.message = 'GPS coordinates unavailable']);
}

class AlertCreationFailed extends SosFailure {
  const AlertCreationFailed([super.message = 'Failed to create emergency alert']);
}

class AlertResolutionFailed extends SosFailure {
  const AlertResolutionFailed([super.message = 'Failed to resolve emergency alert']);
}

class SosUnknownFailure extends SosFailure {
  const SosUnknownFailure([super.message = 'An unknown SOS error occurred']);
}

sealed class SosResult<T> {
  const SosResult();
}

final class SosSuccess<T> extends SosResult<T> {
  final T value;
  const SosSuccess(this.value);
}

final class SosFailed<T> extends SosResult<T> {
  final SosFailure failure;
  const SosFailed(this.failure);
}
