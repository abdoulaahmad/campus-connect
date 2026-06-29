import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/core/utils/polygon_utils.dart';
import 'package:campus_connect/features/map/domain/entities/building.dart';
import 'package:campus_connect/features/map/domain/entities/geo_point.dart';
import 'package:campus_connect/features/map/domain/failures/map_failure.dart';
import 'package:campus_connect/features/map/data/repositories/mock_map_repository.dart';

void main() {
  group('Building Search Test Suite', () {
    late MockMapRepository repository;

    setUp(() {
      repository = MockMapRepository();
    });

    test('search("agriculture") returns Faculty of Agriculture', () async {
      final result = await repository.searchBuildings('agriculture');
      expect(result, isA<MapSuccess<List<Building>>>());
      final list = (result as MapSuccess<List<Building>>).value;
      expect(list.length, 1);
      expect(list.first.name, 'Faculty of Agriculture');
    });

    test('search("library") returns FUD Library', () async {
      final result = await repository.searchBuildings('LIBRARy');
      expect(result, isA<MapSuccess<List<Building>>>());
      final list = (result as MapSuccess<List<Building>>).value;
      expect(list.length, 1);
      expect(list.first.name, 'FUD Library');
    });

    test('search("nonexistent") returns empty list', () async {
      final result = await repository.searchBuildings('nonexistent');
      expect(result, isA<MapSuccess<List<Building>>>());
      final list = (result as MapSuccess<List<Building>>).value;
      expect(list.isEmpty, true);
    });
  });

  group('Polygon Math / Ray-Casting Test Suite', () {
    const List<GeoPoint> squarePolygon = [
      GeoPoint(latitude: 10.0, longitude: 10.0),
      GeoPoint(latitude: 10.0, longitude: 12.0),
      GeoPoint(latitude: 12.0, longitude: 12.0),
      GeoPoint(latitude: 12.0, longitude: 10.0),
    ];

    test('Point strictly inside should return true', () {
      const insidePoint = GeoPoint(latitude: 11.0, longitude: 11.0);
      expect(PolygonUtils.isPointInsidePolygon(insidePoint, squarePolygon), true);
    });

    test('Point strictly outside should return false', () {
      const outsidePoint = GeoPoint(latitude: 13.0, longitude: 13.0);
      expect(PolygonUtils.isPointInsidePolygon(outsidePoint, squarePolygon), false);
    });

    test('findBuildingAtCoordinate finds seeded building correctly', () async {
      final repo = MockMapRepository();
      final result = await repo.getBuildings();
      final list = (result as MapSuccess<List<Building>>).value;

      // Senate Building center is 11.7136, 9.3419. Let's long press close to it.
      const closeToSenate = GeoPoint(latitude: 11.71355, longitude: 9.34185);
      final match = PolygonUtils.findBuildingAtCoordinate(closeToSenate, list);
      expect(match, isNotNull);
      expect(match!.name, 'Senate Building');

      // Point in the middle of nowhere should return null
      const nowhere = GeoPoint(latitude: 0.0, longitude: 0.0);
      final emptyMatch = PolygonUtils.findBuildingAtCoordinate(nowhere, list);
      expect(emptyMatch, isNull);
    });
  });
}
