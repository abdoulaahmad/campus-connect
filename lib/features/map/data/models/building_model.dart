import '../../domain/entities/building.dart';
import '../../domain/entities/geo_point.dart';

class BuildingModel extends Building {
  const BuildingModel({
    required super.id,
    required super.name,
    required super.description,
    required super.category,
    required super.center,
    required super.polygonPoints,
  });

  factory BuildingModel.fromDbMap(
    Map<String, dynamic> buildingMap,
    List<Map<String, dynamic>> pointMaps,
  ) {
    final lat = (buildingMap['center_lat'] as num).toDouble();
    final lng = (buildingMap['center_lng'] as num).toDouble();
    
    // Sort boundary points by sequence
    final sortedPoints = List<Map<String, dynamic>>.from(pointMaps)
      ..sort((a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num));

    final polygonPoints = sortedPoints.map((pt) {
      return GeoPoint(
        latitude: (pt['lat'] as num).toDouble(),
        longitude: (pt['lng'] as num).toDouble(),
      );
    }).toList();

    return BuildingModel(
      id: buildingMap['id'] as String,
      name: buildingMap['name'] as String,
      description: buildingMap['description'] as String,
      category: _parseCategory(buildingMap['category'] as String),
      center: GeoPoint(latitude: lat, longitude: lng),
      polygonPoints: polygonPoints,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'center_lat': center.latitude,
      'center_lng': center.longitude,
    };
  }

  static BuildingCategory _parseCategory(String name) {
    return BuildingCategory.values.firstWhere(
      (cat) => cat.name == name,
      orElse: () => BuildingCategory.academic,
    );
  }
}
