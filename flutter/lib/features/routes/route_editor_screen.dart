import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/map.dart';
import '../../models/waypoint.dart';
import '../../state/route_notifier.dart';
import '../../state/route_state.dart';
import '../../state/routing_provider.dart';
import '../map/waypoint_markers.dart';
import '../map/route_polyline.dart';
import 'editor_stats_sheet.dart';

class RouteEditorScreen extends ConsumerStatefulWidget {
  /// If set, load this route for editing.
  final int? editRouteId;

  /// If set, start in creating mode with these pre-loaded waypoints (GPX import).
  final List<Waypoint>? importedWaypoints;

  const RouteEditorScreen({
    super.key,
    this.editRouteId,
    this.importedWaypoints,
  });

  @override
  ConsumerState<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends ConsumerState<RouteEditorScreen> {
  MaplibreMapController? _mapController;
  Timer? _routingDebounce;
  String? _selectedWaypointId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.editRouteId != null) {
        await ref
            .read(routeProvider.notifier)
            .loadRouteForEditing(widget.editRouteId!);
      } else if (widget.importedWaypoints != null) {
        ref.read(routeProvider.notifier).loadWaypoints(
              widget.importedWaypoints!,
            );
        ref
            .read(routeProvider.notifier)
            .setEditingMode(EditingMode.creating);
        _scheduleRouting();
      } else {
        // Fresh route
        ref.read(routeProvider.notifier).clearAll();
        ref
            .read(routeProvider.notifier)
            .setEditingMode(EditingMode.creating);
      }
    });
  }

  @override
  void dispose() {
    _routingDebounce?.cancel();
    super.dispose();
  }

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
    setState(() {});
  }

  void _addWaypoint(LatLng coords) {
    final notifier = ref.read(routeProvider.notifier);
    notifier.addWaypoint(coords.latitude, coords.longitude);
    _scheduleRouting();
    setState(() => _selectedWaypointId = null);
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
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14,
      ),
    );
  }

  Future<void> _onElevationTap(int index) async {
    final state = ref.read(routeProvider);
    if (state.route == null) return;
    final coords =
        state.route!['geometry']['coordinates'] as List;
    if (index >= coords.length) return;
    final c = coords[index] as List;
    final lon = (c[0] as num).toDouble();
    final lat = (c[1] as num).toDouble();
    ref
        .read(routeProvider.notifier)
        .setElevationMarkerCoord([lon, lat]);
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(lat, lon)),
    );
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(routeProvider);
    final hasChanges = state.waypoints.isNotEmpty;
    if (!hasChanges) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text(
          'Are you sure you want to leave? All information will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _popEditor() {
    ref.read(routeProvider.notifier).clearAll();
    Navigator.pop(context);
  }

  void _deleteSelectedWaypoint() {
    if (_selectedWaypointId == null) return;
    final state = ref.read(routeProvider);
    if (state.waypoints.length <= 1) return;
    ref
        .read(routeProvider.notifier)
        .removeWaypoint(_selectedWaypointId!);
    setState(() => _selectedWaypointId = null);
    _scheduleRouting();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeProvider);
    final canUndo = ref.read(routeProvider.notifier).canUndo;
    final canRedo = ref.read(routeProvider.notifier).canRedo;
    final canDelete = _selectedWaypointId != null &&
        state.waypoints.length > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _onWillPop();
        if (canLeave && mounted) _popEditor();
      },
      child: Scaffold(
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
              onMapLongClick: (_, coords) => _addWaypoint(coords),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
            ),

            // Route polyline
            if (_mapController != null && state.route != null)
              RoutePolylineOverlay(
                mapController: _mapController!,
                geometry: state.route!,
                color: state.routeColor,
              ),

            // Waypoint markers
            if (_mapController != null && state.waypoints.isNotEmpty)
              WaypointMarkersOverlay(
                mapController: _mapController!,
                waypoints: state.waypoints,
                routeColor: state.routeColor,
                selectedWaypointId: _selectedWaypointId,
                onWaypointMoved: (id, lat, lon) {
                  ref
                      .read(routeProvider.notifier)
                      .moveWaypoint(id, lat, lon);
                  _scheduleRouting();
                },
                onWaypointTapped: (id) =>
                    setState(() => _selectedWaypointId =
                        _selectedWaypointId == id ? null : id),
              ),

            // Loading indicator
            if (state.isLoading)
              const Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8,
                      ),
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

            // Top-left back button
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _EditorIconButton(
                    icon: Icons.chevron_left,
                    onPressed: () async {
                      final canLeave = await _onWillPop();
                      if (canLeave && mounted) _popEditor();
                    },
                  ),
                ),
              ),
            ),

            // Top-right button stack
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EditorIconButton(
                        icon: Icons.layers,
                        onPressed: () {
                          // TODO Phase 2: Map layer popover
                        },
                      ),
                      const SizedBox(height: 8),
                      _EditorIconButton(
                        icon: Icons.my_location,
                        onPressed: _centerOnLocation,
                      ),
                      const SizedBox(height: 8),
                      _EditorIconButton(
                        icon: Icons.undo,
                        onPressed: canUndo
                            ? () {
                                ref
                                    .read(routeProvider.notifier)
                                    .undo();
                                _scheduleRouting();
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _EditorIconButton(
                        icon: Icons.redo,
                        onPressed: canRedo
                            ? () {
                                ref
                                    .read(routeProvider.notifier)
                                    .redo();
                                _scheduleRouting();
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _EditorIconButton(
                        icon: Icons.near_me,
                        highlighted: state.isSnapping,
                        onPressed: () => ref
                            .read(routeProvider.notifier)
                            .setIsSnapping(!state.isSnapping),
                        tooltip: state.isSnapping
                            ? 'Snap on'
                            : 'Snap off',
                      ),
                      const SizedBox(height: 8),
                      _EditorIconButton(
                        icon: Icons.delete_outline,
                        onPressed: canDelete
                            ? _deleteSelectedWaypoint
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Editor Stats Sheet
            EditorStatsSheet(
              onElevationTap: _onElevationTap,
              onBack: () async {
                final canLeave = await _onWillPop();
                if (canLeave && mounted) _popEditor();
              },
              onSaved: _popEditor,
              onDeleted: _popEditor,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlighted;
  final String? tooltip;

  const _EditorIconButton({
    required this.icon,
    this.onPressed,
    this.highlighted = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: highlighted
            ? const Color(0xFF3b82f6)
            : onPressed != null
                ? Colors.white
                : Colors.white70,
        borderRadius: BorderRadius.circular(8),
        elevation: onPressed != null ? 2 : 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: highlighted
                  ? Colors.white
                  : onPressed != null
                      ? Colors.black87
                      : Colors.black38,
            ),
          ),
        ),
      ),
    );
  }
}
