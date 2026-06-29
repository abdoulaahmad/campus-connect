import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/building.dart';
import '../../domain/failures/map_failure.dart';
import '../../domain/repositories/i_map_repository.dart';
import '../models/building_model.dart';

class LocalMapRepository implements IMapRepository {
  final AppDatabase _db;
  LocalMapRepository(this._db);

  @override
  Future<MapResult<List<Building>>> getBuildings() async {
    try {
      final database = await _db.database;
      final List<Map<String, dynamic>> buildingMaps = await database.query('local_buildings');
      
      final List<Building> buildings = [];
      for (final bMap in buildingMaps) {
        final String buildingId = bMap['id'] as String;
        final List<Map<String, dynamic>> pointMaps = await database.query(
          'local_building_points',
          where: 'building_id = ?',
          whereArgs: [buildingId],
        );
        buildings.add(BuildingModel.fromDbMap(bMap, pointMaps));
      }
      return MapSuccess(buildings);
    } on DatabaseException catch (e) {
      return MapFailed(MapDatabaseFailure(e.toString()));
    } on FormatException catch (e) {
      return MapFailed(MapDatabaseFailure('Data parsing failure: ${e.message}'));
    }
  }

  @override
  Future<MapResult<Building>> getBuilding(String id) async {
    try {
      final database = await _db.database;
      final List<Map<String, dynamic>> buildingMaps = await database.query(
        'local_buildings',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (buildingMaps.isEmpty) {
        return const MapFailed(BuildingNotFound());
      }
      final List<Map<String, dynamic>> pointMaps = await database.query(
        'local_building_points',
        where: 'building_id = ?',
        whereArgs: [id],
      );
      return MapSuccess(BuildingModel.fromDbMap(buildingMaps.first, pointMaps));
    } on DatabaseException catch (e) {
      return MapFailed(MapDatabaseFailure(e.toString()));
    } on FormatException catch (e) {
      return MapFailed(MapDatabaseFailure('Data parsing failure: ${e.message}'));
    }
  }

  @override
  Future<MapResult<List<Building>>> searchBuildings(String query) async {
    try {
      final database = await _db.database;
      final List<Map<String, dynamic>> buildingMaps = await database.query(
        'local_buildings',
        where: 'name LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
      
      final List<Building> buildings = [];
      for (final bMap in buildingMaps) {
        final String buildingId = bMap['id'] as String;
        final List<Map<String, dynamic>> pointMaps = await database.query(
          'local_building_points',
          where: 'building_id = ?',
          whereArgs: [buildingId],
        );
        buildings.add(BuildingModel.fromDbMap(bMap, pointMaps));
      }
      return MapSuccess(buildings);
    } on DatabaseException catch (e) {
      return MapFailed(MapDatabaseFailure(e.toString()));
    } on FormatException catch (e) {
      return MapFailed(MapDatabaseFailure('Data parsing failure: ${e.message}'));
    }
  }
}
