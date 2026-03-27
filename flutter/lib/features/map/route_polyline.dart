import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class RoutePolylineOverlay extends StatefulWidget {
  final MaplibreMapController mapController;
  final Map<String, dynamic> geometry;
  final String color;

  const RoutePolylineOverlay({
    super.key,
    required this.mapController,
    required this.geometry,
    required this.color,
  });

  @override
  State<RoutePolylineOverlay> createState() => _RoutePolylineOverlayState();
}

class _RoutePolylineOverlayState extends State<RoutePolylineOverlay> {
  Line? _line;

  @override
  void initState() {
    super.initState();
    _drawLine();
  }

  @override
  void didUpdateWidget(RoutePolylineOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry ||
        oldWidget.color != widget.color) {
      _drawLine();
    }
  }

  @override
  void dispose() {
    if (_line != null) {
      widget.mapController.removeLine(_line!);
    }
    super.dispose();
  }

  Future<void> _drawLine() async {
    if (_line != null) {
      await widget.mapController.removeLine(_line!);
      _line = null;
    }

    final coords = (widget.geometry['geometry']['coordinates'] as List)
        .map((c) {
          final pair = c as List;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        })
        .toList();

    if (coords.isEmpty) return;

    _line = await widget.mapController.addLine(
      LineOptions(
        geometry: coords,
        lineColor: widget.color,
        lineWidth: 3.5,
        lineOpacity: 0.9,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
