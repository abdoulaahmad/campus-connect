import '../../features/map/domain/entities/building.dart';
import '../../features/map/domain/entities/geo_point.dart';

/// Static utility for polygon mathematics operations.
abstract final class PolygonUtils {
  /// Ray-Casting algorithm checking if a coordinates point is inside a polygon boundary.
  static bool isPointInsidePolygon(GeoPoint point, List<GeoPoint> polygon) {
    if (polygon.isEmpty) return false;
    
    int i;
    int j = polygon.length - 1;
    bool oddNodes = false;
    final double x = point.longitude;
    final double y = point.latitude;

    for (i = 0; i < polygon.length; i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      if (((yi < y && yj >= y) || (yj < y && yi >= y)) &&
          (xi + (y - yi) / (yj - yi) * (xj - xi) < x)) {
        oddNodes = !oddNodes;
      }
      j = i;
    }
    return oddNodes;
  }

  /// Iterates through building list returning building matching coordinates, or null.
  static Building? findBuildingAtCoordinate(GeoPoint point, List<Building> buildings) {
    for (final building in buildings) {
      if (isPointInsidePolygon(point, building.polygonPoints)) {
        return building;
      }
    }
    return null;
  }
}
