import 'geo_point.dart';

enum BuildingCategory {
  academic,
  hostel,
  administration,
  recreation,
  security,
}

class Building {
  final String id;
  final String name;
  final String description;
  final BuildingCategory category;
  final GeoPoint center;
  final List<GeoPoint> polygonPoints;

  const Building({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.center,
    required this.polygonPoints,
  });
}
