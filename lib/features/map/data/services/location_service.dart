import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/failures/map_failure.dart';
import '../../domain/services/i_location_service.dart';

class LocationService implements ILocationService {
  const LocationService();

  @override
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  @override
  Future<MapResult<GeoPoint>> getCurrentLocation() async {
    try {
      final hasPerm = await checkAndRequestPermission();
      if (!hasPerm) {
        return const MapFailed(LocationPermissionDenied());
      }
      final position = await Geolocator.getCurrentPosition();
      return MapSuccess(GeoPoint(latitude: position.latitude, longitude: position.longitude));
    } on TimeoutException {
      return const MapFailed(MapUnknown('Location request timed out.'));
    } catch (e) {
      return MapFailed(MapUnknown(e.toString()));
    }
  }

  @override
  Stream<MapResult<GeoPoint>> get locationStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map<MapResult<GeoPoint>>((position) {
      return MapSuccess(GeoPoint(latitude: position.latitude, longitude: position.longitude));
    }).handleError((Object error) {
      if (error is PermissionDeniedException) {
        return const MapFailed(LocationPermissionDenied());
      }
      return MapFailed(MapUnknown(error.toString()));
    });
  }
}
