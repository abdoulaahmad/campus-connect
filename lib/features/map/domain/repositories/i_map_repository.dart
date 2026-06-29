import '../entities/building.dart';
import '../failures/map_failure.dart';

abstract class IMapRepository {
  Future<MapResult<List<Building>>> getBuildings();
  Future<MapResult<Building>> getBuilding(String id);
  Future<MapResult<List<Building>>> searchBuildings(String query);
}
