import 'dart:async';
import '../../domain/entities/geo_point.dart';
import '../../domain/failures/map_failure.dart';
import '../../domain/services/i_location_service.dart';

class MockLocationService implements ILocationService {
  final GeoPoint _mockPoint;
  MockLocationService([this._mockPoint = const GeoPoint(latitude: 11.1518, longitude: 7.6496)]);

  @override
  Future<bool> checkAndRequestPermission() async => true;

  @override
  Future<MapResult<GeoPoint>> getCurrentLocation() async {
    return MapSuccess(_mockPoint);
  }

  @override
  Stream<MapResult<GeoPoint>> get locationStream {
    return Stream.value(MapSuccess(_mockPoint));
  }
}
