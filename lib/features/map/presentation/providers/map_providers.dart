import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/building.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/failures/map_failure.dart';
import '../../domain/repositories/i_map_repository.dart';
import '../../domain/services/i_location_service.dart';

/// Future provider supplying buildings
final buildingsProvider = FutureProvider<List<Building>>((ref) async {
  final repo = ref.watch(mapRepositoryProvider);
  final result = await repo.getBuildings();
  return switch (result) {
    MapSuccess(:final value) => value,
    MapFailed(:final failure) => throw failure,
  };
});

/// Filter/Search query state controller
final mapSearchQueryProvider = StateProvider<String>((ref) => '');

/// Building category filter state controller (null means All)
final mapCategoryFilterProvider = StateProvider<BuildingCategory?>((ref) => null);

/// Filtered buildings provider combining list with filters
final filteredBuildingsProvider = Provider<AsyncValue<List<Building>>>((ref) {
  final buildingsAsync = ref.watch(buildingsProvider);
  final query = ref.watch(mapSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(mapCategoryFilterProvider);

  return buildingsAsync.whenData((list) {
    return list.where((b) {
      final matchesQuery = query.isEmpty ||
          b.name.toLowerCase().contains(query) ||
          b.description.toLowerCase().contains(query);
      final matchesCategory = category == null || b.category == category;
      return matchesQuery && matchesCategory;
    }).toList();
  });
});

/// Stream provider tracking current GPS position
final userLocationStreamProvider = StreamProvider<MapResult<GeoPoint>>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.locationStream;
});
