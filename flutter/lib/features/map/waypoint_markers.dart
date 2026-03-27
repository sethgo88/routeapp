import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/waypoint.dart';

/// Renders colored circle markers for all waypoints.
///
/// Visuals (per spec):
///   Start   — green fill, routeColor border, 24px
///   End     — red fill,   routeColor border, 24px
///   Middle  — white fill, routeColor border, 20px, number label
///   Selected — any type gains a yellow border instead of routeColor
class WaypointMarkersOverlay extends StatefulWidget {
  final MaplibreMapController mapController;
  final List<Waypoint> waypoints;
  final String routeColor;
  final String? selectedWaypointId;
  final void Function(String id, double lat, double lon) onWaypointMoved;
  final void Function(String id) onWaypointTapped;

  const WaypointMarkersOverlay({
    super.key,
    required this.mapController,
    required this.waypoints,
    required this.routeColor,
    required this.onWaypointMoved,
    required this.onWaypointTapped,
    this.selectedWaypointId,
  });

  @override
  State<WaypointMarkersOverlay> createState() => _WaypointMarkersOverlayState();
}

class _WaypointMarkersOverlayState extends State<WaypointMarkersOverlay> {
  final Map<String, Symbol> _symbols = {};

  // The last color for which custom images were registered
  String? _registeredColor;
  String? _registeredSelectedId;

  @override
  void initState() {
    super.initState();
    widget.mapController.onSymbolTapped.add(_onSymbolTapped);
    _syncAll();
  }

  @override
  void didUpdateWidget(WaypointMarkersOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final colorChanged = oldWidget.routeColor != widget.routeColor;
    final selectionChanged =
        oldWidget.selectedWaypointId != widget.selectedWaypointId;
    final waypointsChanged = oldWidget.waypoints != widget.waypoints;

    if (colorChanged || selectionChanged || waypointsChanged) {
      _syncAll(forceImages: colorChanged);
    }
  }

  @override
  void dispose() {
    widget.mapController.onSymbolTapped.remove(_onSymbolTapped);
    _removeAllSymbols();
    super.dispose();
  }

  void _onSymbolTapped(Symbol symbol) {
    // Find which waypoint this symbol belongs to
    for (final entry in _symbols.entries) {
      if (entry.value.id == symbol.id) {
        widget.onWaypointTapped(entry.key);
        return;
      }
    }
  }

  Future<void> _removeAllSymbols() async {
    for (final symbol in _symbols.values) {
      try {
        await widget.mapController.removeSymbol(symbol);
      } catch (_) {}
    }
    _symbols.clear();
  }

  Future<void> _syncAll({bool forceImages = false}) async {
    if (forceImages || _registeredColor != widget.routeColor) {
      await _registerImages();
      _registeredColor = widget.routeColor;
    }

    final current = {for (final wp in widget.waypoints) wp.id: wp};
    final existing = Map<String, Symbol>.from(_symbols);

    // Remove symbols for deleted waypoints
    for (final id in existing.keys) {
      if (!current.containsKey(id)) {
        try {
          await widget.mapController.removeSymbol(_symbols[id]!);
        } catch (_) {}
        _symbols.remove(id);
      }
    }

    final total = widget.waypoints.length;
    for (int i = 0; i < widget.waypoints.length; i++) {
      final wp = widget.waypoints[i];
      final isStart = i == 0;
      final isEnd = i == total - 1 && total > 1;
      final isSelected = wp.id == widget.selectedWaypointId;
      final imageKey = _imageKey(i, total, isSelected);
      final position = LatLng(wp.latitude, wp.longitude);

      if (_symbols.containsKey(wp.id)) {
        await widget.mapController.updateSymbol(
          _symbols[wp.id]!,
          SymbolOptions(
            geometry: position,
            iconImage: imageKey,
          ),
        );
      } else {
        final symbol = await widget.mapController.addSymbol(
          SymbolOptions(
            geometry: position,
            iconImage: imageKey,
            iconSize: 1.0,
            iconAnchor: 'center',
            draggable: true,
          ),
        );
        _symbols[wp.id] = symbol;
      }
    }
    _registeredSelectedId = widget.selectedWaypointId;
  }

  String _imageKey(int index, int total, bool selected) {
    final suffix = selected ? '-sel' : '';
    if (index == 0) return 'wp-start$suffix';
    if (index == total - 1 && total > 1) return 'wp-end$suffix';
    return 'wp-mid-${index + 1}$suffix';
  }

  Future<void> _registerImages() async {
    final borderHex = widget.routeColor;
    final borderColor = _hexToColor(borderHex);
    const yellowBorder = Color(0xFFEAB308);

    // Start
    await _addImage(
      'wp-start',
      await _makeCircle(
        fill: const Color(0xFF22C55E),
        border: borderColor,
        diameter: 28,
      ),
    );
    await _addImage(
      'wp-start-sel',
      await _makeCircle(
        fill: const Color(0xFF22C55E),
        border: yellowBorder,
        diameter: 28,
        borderWidth: 3,
      ),
    );

    // End
    await _addImage(
      'wp-end',
      await _makeCircle(
        fill: const Color(0xFFEF4444),
        border: borderColor,
        diameter: 28,
      ),
    );
    await _addImage(
      'wp-end-sel',
      await _makeCircle(
        fill: const Color(0xFFEF4444),
        border: yellowBorder,
        diameter: 28,
        borderWidth: 3,
      ),
    );

    // Middle waypoints 1–30
    for (int i = 1; i <= 30; i++) {
      await _addImage(
        'wp-mid-$i',
        await _makeCircle(
          fill: Colors.white,
          border: borderColor,
          diameter: 24,
          label: '$i',
          labelColor: Colors.black87,
        ),
      );
      await _addImage(
        'wp-mid-$i-sel',
        await _makeCircle(
          fill: Colors.white,
          border: yellowBorder,
          diameter: 24,
          borderWidth: 3,
          label: '$i',
          labelColor: Colors.black87,
        ),
      );
    }
  }

  Future<void> _addImage(String name, Uint8List bytes) async {
    try {
      await widget.mapController.addImage(name, bytes);
    } catch (_) {}
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  static Future<Uint8List> _makeCircle({
    required Color fill,
    required Color border,
    required int diameter,
    String? label,
    Color labelColor = Colors.black87,
    double borderWidth = 2.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = diameter / 2.0;

    // Shadow (subtle)
    canvas.drawCircle(
      Offset(r, r + 1),
      r - 0.5,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Border circle
    canvas.drawCircle(Offset(r, r), r, Paint()..color = border);

    // Fill circle
    canvas.drawCircle(
      Offset(r, r),
      r - borderWidth,
      Paint()..color = fill,
    );

    if (label != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: diameter * 0.42,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: diameter.toDouble());
      textPainter.paint(
        canvas,
        Offset(
          (diameter - textPainter.width) / 2,
          (diameter - textPainter.height) / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(diameter, diameter);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
