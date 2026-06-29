import '../../domain/entities/building.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/failures/map_failure.dart';
import '../../domain/repositories/i_map_repository.dart';

class MockMapRepository implements IMapRepository {
  final List<Building> _seedBuildings = _generateSeedBuildings();

  @override
  Future<MapResult<List<Building>>> getBuildings() async {
    return MapSuccess(_seedBuildings);
  }

  @override
  Future<MapResult<Building>> getBuilding(String id) async {
    final b = _seedBuildings.firstWhere(
      (element) => element.id == id,
      orElse: () => const Building(
        id: '',
        name: '',
        description: '',
        category: BuildingCategory.academic,
        center: GeoPoint(latitude: 0, longitude: 0),
        polygonPoints: [],
      ),
    );
    if (b.id.isEmpty) {
      return const MapFailed(BuildingNotFound());
    }
    return MapSuccess(b);
  }

  @override
  Future<MapResult<List<Building>>> searchBuildings(String query) async {
    final results = _seedBuildings.where((b) {
      final q = query.toLowerCase();
      return b.name.toLowerCase().contains(q) || b.description.toLowerCase().contains(q);
    }).toList();
    return MapSuccess(results);
  }

  static List<Building> _generateSeedBuildings() {
    final centers = [
      const GeoPoint(latitude: 11.7136, longitude: 9.3419), // Senate Building
      const GeoPoint(latitude: 11.7145, longitude: 9.3430), // FUD Library
      const GeoPoint(latitude: 11.7139, longitude: 9.3443), // Convocation Arena
      const GeoPoint(latitude: 11.7154, longitude: 9.3413), // Faculty of Science
      const GeoPoint(latitude: 11.7163, longitude: 9.3399), // Faculty of Agriculture
      const GeoPoint(latitude: 11.7124, longitude: 9.3390), // Faculty of Arts and Social Sciences
      const GeoPoint(latitude: 11.7181, longitude: 9.3379), // College of Health Sciences
      const GeoPoint(latitude: 11.7111, longitude: 9.3406), // General Lecture Theatre
      const GeoPoint(latitude: 11.7120, longitude: 9.3440), // Student Center
      const GeoPoint(latitude: 11.7107, longitude: 9.3426), // University Clinic
      const GeoPoint(latitude: 11.7071, longitude: 9.3456), // Main Gate
      const GeoPoint(latitude: 11.7194, longitude: 9.3363), // Second Gate (Aba)
      const GeoPoint(latitude: 11.7091, longitude: 9.3373), // Male Hostel Complex
      const GeoPoint(latitude: 11.7100, longitude: 9.3359), // Female Hostel Complex
      const GeoPoint(latitude: 11.7170, longitude: 9.3453), // Sports Complex
    ];

    final names = [
      "Senate Building", "FUD Library", "Convocation Arena",
      "Faculty of Science", "Faculty of Agriculture", "Faculty of Arts and Social Sciences",
      "College of Health Sciences", "General Lecture Theatre", "Student Center",
      "University Clinic", "Main Gate", "Second Gate (Aba)",
      "Male Hostel Complex", "Female Hostel Complex", "Sports Complex"
    ];

    final descriptions = [
      "Administrative headquarters and Vice Chancellor's office of FUD.",
      "The main university library containing research resources and digital hubs.",
      "Open-air square for convocations, events, and speech broadcasts.",
      "Departments of Computer Science, Physics, Chemistry, and Mathematics.",
      "FUD agricultural research departments and laboratories.",
      "Departments of Economics, Sociology, and Political Science.",
      "Academic building for clinical and health sciences departments.",
      "Main lecture hall for general studies and matriculation ceremonies.",
      "Hub for student union services, dining, and shops.",
      "The primary campus health center and emergency first-aid clinic.",
      "The primary northern gate connecting the FUD campus to the main highway.",
      "Alternative campus access gate located near the agricultural fields.",
      "Undergraduate male student residence halls.",
      "Undergraduate female student residence halls.",
      "Main campus athletic track, soccer field, and gymnasium."
    ];

    final categories = [
      BuildingCategory.administration, BuildingCategory.academic, BuildingCategory.recreation,
      BuildingCategory.academic, BuildingCategory.academic, BuildingCategory.academic,
      BuildingCategory.academic, BuildingCategory.academic, BuildingCategory.recreation,
      BuildingCategory.security, BuildingCategory.security, BuildingCategory.security,
      BuildingCategory.hostel, BuildingCategory.hostel, BuildingCategory.recreation
    ];

    return List.generate(15, (index) {
      final id = 'B${(index + 1).toString().padLeft(3, '0')}';
      final center = centers[index];
      
      final polygon = [
        GeoPoint(latitude: center.latitude - 0.00015, longitude: center.longitude - 0.00015),
        GeoPoint(latitude: center.latitude - 0.00015, longitude: center.longitude + 0.00015),
        GeoPoint(latitude: center.latitude + 0.00015, longitude: center.longitude + 0.00015),
        GeoPoint(latitude: center.latitude + 0.00015, longitude: center.longitude - 0.00015),
      ];

      return Building(
        id: id,
        name: names[index],
        description: descriptions[index],
        category: categories[index],
        center: center,
        polygonPoints: polygon,
      );
    });
  }
}
