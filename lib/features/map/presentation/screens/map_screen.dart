import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/utils/polygon_utils.dart';
import '../../domain/entities/building.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/failures/map_failure.dart';
import '../providers/map_providers.dart';
import '../widgets/campus_map_view.dart';
import '../../../../core/providers/core_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  
  // FUD Dutse, Jigawa center coordinate
  static const GeoPoint _campusCenter = GeoPoint(latitude: 11.7136, longitude: 9.3419);

  Building? _selectedBuilding;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _mapController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectBuilding(Building building) {
    setState(() {
      _selectedBuilding = building;
      _showSuggestions = false;
    });
    _searchFocusNode.unfocus();
    _searchController.text = building.name;
    _mapController.move(
      ll.LatLng(building.center.latitude, building.center.longitude),
      17.5,
    );
    _showBuildingDetailsSheet(building);
  }

  void _showBuildingDetailsSheet(Building building) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final categoryColor = _getCategoryColor(building.category);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        building.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: categoryColor.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Text(
                    building.category.name.toUpperCase(),
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  building.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${building.center.latitude.toStringAsFixed(5)}, ${building.center.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(BuildingCategory cat) {
    return switch (cat) {
      BuildingCategory.academic => const Color(0xFF00B0FF),       // Secondary Blue
      BuildingCategory.hostel => Colors.greenAccent,
      BuildingCategory.administration => const Color(0xFFE040FB), // Purple Accent
      BuildingCategory.recreation => Colors.orangeAccent,
      BuildingCategory.security => const Color(0xFFFF5252),       // Light Red
    };
  }

  Future<void> _centerOnUser() async {
    final locationService = ref.read(locationServiceProvider);
    final isEnabled = await locationService.checkAndRequestPermission();
    
    if (!isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied or GPS disabled.'),
            backgroundColor: Color(0xFF880E4F), // Primary Crimson
          ),
        );
      }
      return;
    }

    final result = await locationService.getCurrentLocation();
    if (result is MapSuccess<GeoPoint>) {
      _mapController.move(
        ll.LatLng(result.value.latitude, result.value.longitude),
        17.0,
      );
    } else if (result is MapFailed<GeoPoint> && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failure.message),
          backgroundColor: const Color(0xFF880E4F),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buildingsAsync = ref.watch(buildingsProvider);
    final filteredBuildingsAsync = ref.watch(filteredBuildingsProvider);
    final userLocationAsync = ref.watch(userLocationStreamProvider);
    final activeCategory = ref.watch(mapCategoryFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // ── Map Layer ──────────────────────────────────────────────────────
          CampusMapView(
            mapController: _mapController,
            buildings: filteredBuildingsAsync.maybeWhen(
              data: (list) => list,
              orElse: () => const [],
            ),
            selectedBuilding: _selectedBuilding,
            onBuildingTapped: _selectBuilding,
            onTap: (_) {
              if (_showSuggestions) {
                setState(() => _showSuggestions = false);
                _searchFocusNode.unfocus();
              }
            },
            extraMarkers: [
              ...?userLocationAsync.maybeWhen(
                data: (result) {
                  if (result is MapSuccess<GeoPoint>) {
                    return [
                      Marker(
                        point: ll.LatLng(result.value.latitude, result.value.longitude),
                        width: 40.0,
                        height: 40.0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  }
                  return null;
                },
                orElse: () => null,
              ),
            ],
          ),

          // ── Search & Suggestions ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search campus buildings...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(mapSearchQueryProvider.notifier).state = '';
                                  setState(() {
                                    _selectedBuilding = null;
                                    _showSuggestions = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onChanged: (val) {
                        ref.read(mapSearchQueryProvider.notifier).state = val;
                        setState(() {
                          _showSuggestions = val.isNotEmpty;
                        });
                      },
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          setState(() => _showSuggestions = true);
                        }
                      },
                    ),
                  ),
                  if (_showSuggestions)
                    Consumer(
                      builder: (context, ref, child) {
                        final searchResultsAsync = ref.watch(filteredBuildingsProvider);
                        return searchResultsAsync.maybeWhen(
                          data: (results) {
                            if (results.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (context, index) {
                                  final b = results[index];
                                  final color = _getCategoryColor(b.category);
                                  return ListTile(
                                    leading: Icon(Icons.location_on, color: color, size: 20),
                                    title: Text(
                                      b.name,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      b.category.name,
                                      style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
                                    ),
                                    onTap: () => _selectBuilding(b),
                                  );
                                },
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // ── Horizontal Category Filters ────────────────────────────────────
          Positioned(
            top: 80 + MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: activeCategory == null,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(mapCategoryFilterProvider.notifier).state = null;
                      }
                    },
                    selectedColor: const Color(0xFF880E4F),
                    backgroundColor: const Color(0xFF1E1E1E),
                    labelStyle: TextStyle(
                      color: activeCategory == null ? Colors.white : Colors.white70,
                    ),
                    checkmarkColor: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  ...BuildingCategory.values.map((cat) {
                    final color = _getCategoryColor(cat);
                    final isSelected = activeCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat.name[0].toUpperCase() + cat.name.substring(1)),
                        selected: isSelected,
                        onSelected: (selected) {
                          ref.read(mapCategoryFilterProvider.notifier).state = selected ? cat : null;
                        },
                        selectedColor: color.withValues(alpha: 0.3),
                        backgroundColor: const Color(0xFF1E1E1E),
                        labelStyle: TextStyle(
                          color: isSelected ? color : Colors.white70,
                        ),
                        checkmarkColor: color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? color : Colors.white10,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Geolocator Centering FAB ───────────────────────────────────────
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: _centerOnUser,
              backgroundColor: const Color(0xFF880E4F), // Brand Primary Crimson
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Offline Notice Overlay if GPS services are down
          userLocationAsync.maybeWhen(
            data: (result) {
              if (result is MapFailed<GeoPoint> &&
                  (result.failure is LocationPermissionDenied ||
                      result.failure is LocationServiceDisabled)) {
                return Positioned(
                  bottom: 24,
                  left: 24,
                  right: 96,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF322A2D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF880E4F), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_off, color: Colors.orangeAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            result.failure is LocationPermissionDenied
                                ? 'Offline GPS: location permission denied.'
                                : 'Offline GPS: location services disabled.',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
