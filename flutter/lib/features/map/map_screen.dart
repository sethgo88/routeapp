import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/map.dart';
import '../../models/saved_route.dart';
import '../../services/db.dart' as db;
import '../gpx/gpx_exporter.dart';
import '../routes/route_list_sheet.dart';
import '../routes/route_detail_modal.dart';
import '../routes/route_editor_screen.dart';
import '../routes/route_list_modal.dart' show savedRoutesProvider;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MaplibreMapController? _mapController;
  bool _mapStyleLoaded = false;
  SavedRoute? _detailRoute;
  List<SavedRoute> _loadedRoutes = [];

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() => _mapStyleLoaded = true);
    _refreshRouteLayers();
  }

  Future<void> _refreshRouteLayers() async {
    final controller = _mapController;
    if (controller == null || !_mapStyleLoaded) return;

    final routes = await db.listRoutes();
    _loadedRoutes = routes;

    final features = routes
        .map((r) => {
              'type': 'Feature',
              'geometry': r.geometry['geometry'],
              'properties': {
                'routeId': r.id,
                'color': r.color,
              },
            })
        .toList();

    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    try {
      await controller.removeLayer('routes-layer');
    } catch (_) {}
    try {
      await controller.removeSource('routes-source');
    } catch (_) {}

    await controller.addGeoJsonSource('routes-source', geoJson);
    await controller.addLineLayer(
      'routes-source',
      'routes-layer',
      const LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 3.5,
        lineOpacity: 0.9,
      ),
    );
  }

  Future<void> _onMapClick(Point<double> point, LatLng coordinates) async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      final features = await controller.queryRenderedFeatures(
        point,
        ['routes-layer'],
        null,
      );
      if (features.isNotEmpty) {
        final props = features.first['properties'];
        final routeId = props is Map ? props['routeId'] as int? : null;
        if (routeId != null) {
          final route = await db.getRoute(routeId);
          if (route != null && mounted) {
            setState(() => _detailRoute = route);
            return;
          }
        }
      }
    } catch (_) {}

    // Dismiss detail modal on empty map tap
    if (_detailRoute != null && mounted) {
      setState(() => _detailRoute = null);
    }
  }

  Future<void> _centerOnLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14,
      ),
    );
  }

  Future<void> _openNewEditor() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const RouteEditorScreen()),
    );
    if (mounted) {
      ref.invalidate(savedRoutesProvider);
      await _refreshRouteLayers();
    }
  }

  Future<void> _openEditorForRoute(int routeId) async {
    setState(() => _detailRoute = null);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteEditorScreen(editRouteId: routeId),
      ),
    );
    if (mounted) {
      ref.invalidate(savedRoutesProvider);
      await _refreshRouteLayers();
    }
  }

  Future<void> _exportRoute(SavedRoute route) async {
    // Load elevation data from the saved geometry if available
    final gpx = exportGpx(
      geometry: route.geometry,
      elevationData: const [],
      name: route.name,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${route.name.replaceAll(' ', '_')}.gpx');
    await file.writeAsString(gpx);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: route.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          MaplibreMap(
            styleString: mapStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(37.7749, -122.4194),
              zoom: 12,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: _onMapClick,
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
          ),

          // Top-left: Settings gear
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _MapIconButton(
                  icon: Icons.settings,
                  onPressed: () {
                    // TODO Phase 2: Settings screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings — coming soon')),
                    );
                  },
                ),
              ),
            ),
          ),

          // Top-right: Layers, GPS, Search, +
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapIconButton(
                      icon: Icons.layers,
                      onPressed: () {
                        // TODO Phase 2: Map layer popover
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Map layers — coming soon')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _MapIconButton(
                      icon: Icons.my_location,
                      onPressed: _centerOnLocation,
                    ),
                    const SizedBox(height: 8),
                    _MapIconButton(
                      icon: Icons.search,
                      onPressed: () {
                        // TODO Phase 2: Search modal
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Search — coming soon')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _MapIconButton(
                      icon: Icons.add,
                      onPressed: _openNewEditor,
                      highlighted: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Route List Sheet — always peeking at bottom
          RouteListSheet(
            onRouteSelected: _openEditorForRoute,
            onNewRoute: _openNewEditor,
            onAfterImport: _refreshRouteLayers,
          ),

          // Route Detail Modal — fades in over map
          if (_detailRoute != null)
            RouteDetailModal(
              route: _detailRoute!,
              onClose: () => setState(() => _detailRoute = null),
              onEdit: () => _openEditorForRoute(_detailRoute!.id),
              onExport: () => _exportRoute(_detailRoute!),
            ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlighted;

  const _MapIconButton({
    required this.icon,
    this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? const Color(0xFF3b82f6) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: highlighted ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
