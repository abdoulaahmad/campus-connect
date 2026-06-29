import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/features/map/domain/entities/building.dart';
import 'package:campus_connect/features/map/domain/entities/geo_point.dart';
import 'package:campus_connect/features/map/domain/failures/map_failure.dart';
import 'package:campus_connect/features/map/data/models/building_model.dart';
import 'package:campus_connect/features/map/data/repositories/mock_map_repository.dart';

void main() {
  group('Building Model & Serialization', () {
    test('toMap() and fromDbMap() should match', () {
      const model = BuildingModel(
        id: 'B999',
        name: 'Test Hall',
        description: 'A test building description.',
        category: BuildingCategory.hostel,
        center: GeoPoint(latitude: 11.123, longitude: 7.456),
        polygonPoints: [
          GeoPoint(latitude: 11.122, longitude: 7.455),
          GeoPoint(latitude: 11.122, longitude: 7.457),
          GeoPoint(latitude: 11.124, longitude: 7.457),
          GeoPoint(latitude: 11.124, longitude: 7.455),
        ],
      );

      final buildingMap = model.toDbMap();
      final pointMaps = model.polygonPoints.asMap().entries.map((entry) {
        return {
          'building_id': model.id,
          'sequence': entry.key,
          'lat': entry.value.latitude,
          'lng': entry.value.longitude,
        };
      }).toList();

      final parsedModel = BuildingModel.fromDbMap(buildingMap, pointMaps);

      expect(parsedModel.id, model.id);
      expect(parsedModel.name, model.name);
      expect(parsedModel.description, model.description);
      expect(parsedModel.category, model.category);
      expect(parsedModel.center, model.center);
      expect(parsedModel.polygonPoints, model.polygonPoints);
    });
  });

  group('MockMapRepository Test Suite', () {
    late MockMapRepository repository;

    setUp(() {
      repository = MockMapRepository();
    });

    test('getBuildings() returns 15 seeded buildings', () async {
      final result = await repository.getBuildings();
      expect(result, isA<MapSuccess<List<Building>>>());
      
      final buildings = (result as MapSuccess<List<Building>>).value;
      expect(buildings.length, 15);
      expect(buildings.first.id, 'B001');
      expect(buildings.first.name, 'Senate Building');
      expect(buildings.first.category, BuildingCategory.administration);
    });

    test('getBuilding(id) returns correct building or failure', () async {
      final successResult = await repository.getBuilding('B002');
      expect(successResult, isA<MapSuccess<Building>>());
      final building = (successResult as MapSuccess<Building>).value;
      expect(building.name, 'FUD Library');
      expect(building.category, BuildingCategory.academic);

      final failResult = await repository.getBuilding('B999');
      expect(failResult, isA<MapFailed<Building>>());
      final failure = (failResult as MapFailed<Building>).failure;
      expect(failure, isA<BuildingNotFound>());
    });
  });
}
