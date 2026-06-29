import 'package:meta/meta.dart';

@immutable
sealed class MapFailure {
  final String message;
  const MapFailure(this.message);

  @override
  String toString() => message;
}

class BuildingNotFound extends MapFailure {
  const BuildingNotFound([super.message = 'Building not found']);
}

class MapDatabaseFailure extends MapFailure {
  const MapDatabaseFailure([super.message = 'Local map database error']);
}

class LocationPermissionDenied extends MapFailure {
  const LocationPermissionDenied([super.message = 'Location permission was denied']);
}

class LocationServiceDisabled extends MapFailure {
  const LocationServiceDisabled([super.message = 'Location services are disabled']);
}

class MapUnknown extends MapFailure {
  const MapUnknown([super.message = 'An unknown map error occurred']);
}

sealed class MapResult<T> {
  const MapResult();
}

final class MapSuccess<T> extends MapResult<T> {
  final T value;
  const MapSuccess(this.value);
}

final class MapFailed<T> extends MapResult<T> {
  final MapFailure failure;
  const MapFailed(this.failure);
}
