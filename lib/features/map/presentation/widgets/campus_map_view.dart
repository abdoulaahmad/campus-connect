import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../domain/entities/building.dart';
import '../../domain/entities/geo_point.dart';

class CampusMapView extends StatelessWidget {
  final MapController? mapController;
  final List<Building> buildings;
  final Building? selectedBuilding;
  final List<Marker> extraMarkers;
  final void Function(Building)? onBuildingTapped;
  final void Function(ll.LatLng)? onTap;
  final ll.LatLng initialCenter;
  final double initialZoom;

  const CampusMapView({
    super.key,
    this.mapController,
    this.buildings = const [],
    this.selectedBuilding,
    this.extraMarkers = const [],
    this.onBuildingTapped,
    this.onTap,
    this.initialCenter = const ll.LatLng(11.7136, 9.3419),
    this.initialZoom = 16.0,
  });

  Color _getCategoryColor(BuildingCategory cat) {
    return switch (cat) {
      BuildingCategory.academic => const Color(0xFF00B0FF),
      BuildingCategory.hostel => Colors.greenAccent,
      BuildingCategory.administration => const Color(0xFFE040FB),
      BuildingCategory.recreation => Colors.orangeAccent,
      BuildingCategory.security => const Color(0xFFFF5252),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        maxZoom: 18.5,
        minZoom: 14.0,
        onTap: (tapPosition, point) {
          if (onTap != null) {
            onTap!(point);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.aus.campusconnect',
        ),
        // Building polygons
        PolygonLayer(
          polygons: buildings.map((b) {
            final color = _getCategoryColor(b.category);
            return Polygon(
              points: b.polygonPoints
                  .map((p) => ll.LatLng(p.latitude, p.longitude))
                  .toList(),
              color: color.withValues(alpha: 0.18),
              borderColor: color,
              borderStrokeWidth: 2.0,
            );
          }).toList(),
        ),
        // Building Center Markers
        MarkerLayer(
          markers: buildings.map((b) {
            final color = _getCategoryColor(b.category);
            final isSelected = selectedBuilding?.id == b.id;
            return Marker(
              point: ll.LatLng(b.center.latitude, b.center.longitude),
              width: 50.0,
              height: 50.0,
              child: GestureDetector(
                onTap: () {
                  if (onBuildingTapped != null) {
                    onBuildingTapped!(b);
                  }
                },
                child: Icon(
                  Icons.location_on,
                  color: isSelected ? Colors.white : color,
                  size: isSelected ? 38.0 : 30.0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // Extra custom markers (e.g. user location, emergency alerts)
        if (extraMarkers.isNotEmpty) MarkerLayer(markers: extraMarkers),
      ],
    );
  }
}
