import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/waypoint.dart';

class WaypointMarkersOverlay extends StatefulWidget {
  final MaplibreMapController mapController;
  final List<Waypoint> waypoints;
  final void Function(String id, double lat, double lon) onWaypointMoved;

  const WaypointMarkersOverlay({
    super.key,
    required this.mapController,
    required this.waypoints,
    required this.onWaypointMoved,
  });

  @override
  State<WaypointMarkersOverlay> createState() => _WaypointMarkersOverlayState();
}

class _WaypointMarkersOverlayState extends State<WaypointMarkersOverlay> {
  final Map<String, Symbol> _symbols = {};

  @override
  void didUpdateWidget(WaypointMarkersOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMarkers();
  }

  @override
  void initState() {
    super.initState();
    _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    final current = {for (final wp in widget.waypoints) wp.id: wp};
    final existing = Map<String, Symbol>.from(_symbols);

    // Remove symbols for deleted waypoints
    for (final id in existing.keys) {
      if (!current.containsKey(id)) {
        await widget.mapController.removeSymbol(_symbols[id]!);
        _symbols.remove(id);
      }
    }

    // Add or update symbols
    for (final wp in widget.waypoints) {
      final position = LatLng(wp.latitude, wp.longitude);
      if (_symbols.containsKey(wp.id)) {
        await widget.mapController.updateSymbol(
          _symbols[wp.id]!,
          SymbolOptions(geometry: position, textField: wp.label),
        );
      } else {
        final symbol = await widget.mapController.addSymbol(
          SymbolOptions(
            geometry: position,
            iconImage: 'marker-15',
            iconSize: 2.0,
            textField: wp.label,
            textOffset: const Offset(0, 1.5),
            textColor: '#1e3a5f',
            draggable: true,
          ),
        );
        _symbols[wp.id] = symbol;
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
