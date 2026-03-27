import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/map_layers.dart';
import '../../models/saved_route.dart';
import '../../services/db.dart' as db;
import '../../state/settings_provider.dart';
import '../gpx/gpx_exporter.dart';
import '../offline/downloaded_regions_sheet.dart';
import '../routes/route_list_sheet.dart';
import '../routes/route_detail_modal.dart';
import '../routes/route_editor_screen.dart';
import '../routes/route_list_modal.dart' show savedRoutesProvider;
import '../settings/settings_screen.dart';
import 'layer_popover.dart';
import 'search_modal.dart';

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
  bool _showLayerPopover = false;
  bool _showOfflineSheet = false;

  @override
  void initState() {
    super.initState();
    // Initialize active layer from settings after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = await ref.read(settingsProvider.future);
      if (mounted &&
          ref.read(activeLayerProvider) == null) {
        ref.read(activeLayerProvider.notifier).state = settings.defaultLayer;
      }
    });
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() => _mapStyleLoaded = true);
    _refreshRouteLayers();
  }

  MapLayer get _activeLayer =>
      ref.read(activeLayerProvider) ??
      ref.read(settingsProvider).value?.defaultLayer ??
      MapLayer.trail;

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

    // Dismiss layer popover on map tap.
    if (_showLayerPopover) {
      setState(() => _showLayerPopover = false);
      return;
    }

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

    // Dismiss detail modal on empty map tap.
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

  void _onLayerSelected(MapLayer layer) {
    setState(() => _showLayerPopover = false);
    ref.read(activeLayerProvider.notifier).state = layer;
    ref.read(settingsProvider.notifier).setDefaultLayer(layer);
    // Reload map style.
    setState(() => _mapStyleLoaded = false);
    _mapController?.setStyleString(layer.styleUrl);
    // _onStyleLoaded will be called by the map and set _mapStyleLoaded = true.
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted && result == 'offline') {
      setState(() => _showOfflineSheet = true);
    }
  }

  Future<void> _openSettingsFromSheet() async {
    setState(() => _showOfflineSheet = false);
    await _openSettings();
  }

  void _openSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, _, __) => SearchModal(
          onLocationSelected: (coord) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(coord, 14),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to layer changes from settings screen or other surfaces.
    ref.listen<MapLayer?>(activeLayerProvider, (prev, next) {
      if (next != null && prev != next && _mapController != null) {
        setState(() => _mapStyleLoaded = false);
        _mapController!.setStyleString(next.styleUrl);
      }
    });

    final activeLayer = ref.watch(activeLayerProvider) ??
        ref.watch(settingsProvider).value?.defaultLayer ??
        MapLayer.trail;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          MaplibreMap(
            styleString: activeLayer.styleUrl,
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
                  onPressed: () => _openSettings(),
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
                      highlighted: _showLayerPopover,
                      onPressed: () => setState(
                          () => _showLayerPopover = !_showLayerPopover),
                    ),
                    const SizedBox(height: 8),
                    _MapIconButton(
                      icon: Icons.my_location,
                      onPressed: _centerOnLocation,
                    ),
                    const SizedBox(height: 8),
                    _MapIconButton(
                      icon: Icons.search,
                      onPressed: _openSearch,
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

          // Layer popover — tap-outside dismissal underlay
          if (_showLayerPopover)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showLayerPopover = false),
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          // Layer popover — positioned left of the layers button
          if (_showLayerPopover)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  // right: button_width(42) + outer_padding(8) + gap(4) = 54
                  padding: const EdgeInsets.only(top: 8, right: 54),
                  child: LayerPopover(
                    activeLayer: activeLayer,
                    onLayerSelected: _onLayerSelected,
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
              imperial: ref.watch(settingsProvider).value?.isImperial ?? false,
            ),

          // Downloaded Regions Sheet — shown when navigating from Settings
          if (_showOfflineSheet)
            DownloadedRegionsSheet(
              onBackToSettings: _openSettingsFromSheet,
              onZoomToBounds: (bounds) {
                setState(() => _showOfflineSheet = false);
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    bounds,
                    left: 40,
                    top: 40,
                    right: 40,
                    bottom: 40,
                  ),
                );
              },
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
