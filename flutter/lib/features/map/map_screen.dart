import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/map.dart';
import '../../state/route_notifier.dart';
import '../../state/route_state.dart';
import '../../state/routing_provider.dart';
import 'waypoint_markers.dart';
import 'route_polyline.dart';
import '../elevation/elevation_profile.dart';
import '../routes/controls_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MaplibreMapController? _mapController;
  Timer? _longPressTimer;
  LatLng? _longPressStart;
  Timer? _routingDebounce;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _routingDebounce?.cancel();
    super.dispose();
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
  }

  void _onLongPressStart(LatLng coords) {
    _longPressStart = coords;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      _addWaypoint(coords);
    });
  }

  void _onLongPressEnd() {
    _longPressTimer?.cancel();
  }

  void _addWaypoint(LatLng coords) {
    final notifier = ref.read(routeProvider.notifier);
    final mode = ref.read(routeProvider).editingMode;
    if (mode == EditingMode.view) {
      notifier.setEditingMode(EditingMode.creating);
    }
    notifier.addWaypoint(coords.latitude, coords.longitude);
    _scheduleRouting();
  }

  void _scheduleRouting() {
    _routingDebounce?.cancel();
    _routingDebounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(routingProvider.notifier).triggerRouting();
    });
  }

  Future<void> _centerOnLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);

    // Fly to focus coordinate when elevation chart is tapped
    ref.listen(routeProvider.select((s) => s.focusCoordinate), (_, coord) {
      final c = coord as List<double>?;
      if (c != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(c[1], c[0])),
        );
        ref.read(routeProvider.notifier).setElevationMarkerCoord(c);
        ref.read(routeProvider.notifier).setFocusCoordinate(null);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onLongPressStart: (details) {
              // MapLibre handles its own touch; we use MapLibre's onLongPress instead
            },
            child: MaplibreMap(
              styleString: mapStyleUrl,
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.7749, -122.4194),
                zoom: 12,
              ),
              onMapCreated: _onMapCreated,
              onMapLongClick: (_, coords) => _addWaypoint(coords),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
            ),
          ),

          // Route polyline overlay
          if (_mapController != null && routeState.route != null)
            RoutePolylineOverlay(
              mapController: _mapController!,
              geometry: routeState.route!,
              color: routeState.routeColor,
            ),

          // Waypoint markers overlay
          if (_mapController != null && routeState.waypoints.isNotEmpty)
            WaypointMarkersOverlay(
              mapController: _mapController!,
              waypoints: routeState.waypoints,
              onWaypointMoved: (id, lat, lon) {
                ref.read(routeProvider.notifier).moveWaypoint(id, lat, lon);
                _scheduleRouting();
              },
            ),

          // Loading indicator
          if (routeState.isLoading)
            const Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Routing…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // GPS location button
          Positioned(
            right: 16,
            bottom: routeState.elevationData.isNotEmpty ? 280 : 100,
            child: FloatingActionButton.small(
              heroTag: 'gps',
              onPressed: _centerOnLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Elevation profile (shown when route has elevation data)
          if (routeState.elevationData.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ElevationProfile(
                elevationData: routeState.elevationData,
                onTap: (coord) =>
                    ref.read(routeProvider.notifier).setFocusCoordinate(coord),
              ),
            ),

          // Controls panel
          Positioned(
            left: 16,
            right: 16,
            bottom: routeState.elevationData.isNotEmpty ? 220 : 16,
            child: ControlsPanel(
              onLocationCenter: _centerOnLocation,
              onScheduleRouting: _scheduleRouting,
            ),
          ),
        ],
      ),
    );
  }
}
