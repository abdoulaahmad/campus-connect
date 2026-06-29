import '../entities/geo_point.dart';
import '../failures/map_failure.dart';

abstract class ILocationService {
  Stream<MapResult<GeoPoint>> get locationStream;
  Future<MapResult<GeoPoint>> getCurrentLocation();
  Future<bool> checkAndRequestPermission();
}
