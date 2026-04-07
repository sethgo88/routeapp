import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/waypoint.dart';

/// Renders colored circle markers for all waypoints, midpoint-insert dots,
/// and drag-preview lines.
///
/// Visuals (per spec):
///   Start         — green fill, routeColor border, 28 px
///   End           — red fill,   routeColor border, 28 px
///   Middle        — white fill, routeColor border, 24 px, number label
///   Midpoint dot  — routeColor fill, 14 px, no label — blends into route line
///   Selected      — any type gains a yellow border
///   Drag preview  — gray lines from neighbors to current drag position
class WaypointMarkersOverlay extends StatefulWidget {
  final MaplibreMapController mapController;
  final List<Waypoint> waypoints;
  final String routeColor;
  final String? selectedWaypointId;
  final void Function(String id, double lat, double lon) onWaypointMoved;
  final void Function(String id) onWaypointTapped;
  final void Function(int afterIndex, double lat, double lon) onMidpointInserted;
  final VoidCallback? onDragStarted;

  const WaypointMarkersOverlay({
    super.key,
    required this.mapController,
    required this.waypoints,
    required this.routeColor,
    required this.onWaypointMoved,
    required this.onWaypointTapped,
    required this.onMidpointInserted,
    this.selectedWaypointId,
    this.onDragStarted,
  });

  @override
  State<WaypointMarkersOverlay> createState() => _WaypointMarkersOverlayState();
}

class _WaypointMarkersOverlayState extends State<WaypointMarkersOverlay> {
  // waypointId → Symbol
  final Map<String, Symbol> _symbols = {};
  // segmentIndex → midpoint Symbol
  final Map<int, Symbol> _midpointSymbols = {};

  String? _registeredColor;

  // Drag preview state
  String? _draggingWaypointId;
  Line? _dragLine1;
  Line? _dragLine2;

  @override
  void initState() {
    super.initState();
    widget.mapController.onSymbolTapped.add(_onSymbolTapped);
    widget.mapController.onFeatureDrag.add(_onFeatureDrag);
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
    widget.mapController.onFeatureDrag.remove(_onFeatureDrag);
    _removeAllSymbols();
    _clearDragPreview();
    super.dispose();
  }

  // ─── Symbol tap handler ───────────────────────────────────────────────────

  void _onSymbolTapped(Symbol symbol) {
    // Check midpoint insert symbols first
    for (final entry in _midpointSymbols.entries) {
      if (entry.value.id == symbol.id) {
        final segIdx = entry.key;
        if (segIdx >= widget.waypoints.length - 1) return;
        final wp1 = widget.waypoints[segIdx];
        final wp2 = widget.waypoints[segIdx + 1];
        final midLat = (wp1.latitude + wp2.latitude) / 2;
        final midLon = (wp1.longitude + wp2.longitude) / 2;
        widget.onMidpointInserted(segIdx, midLat, midLon);
        return;
      }
    }
    // Check waypoint symbols
    for (final entry in _symbols.entries) {
      if (entry.value.id == symbol.id) {
        widget.onWaypointTapped(entry.key);
        return;
      }
    }
  }

  // ─── Drag handler ─────────────────────────────────────────────────────────

  void _onFeatureDrag(
    Point<double> point,
    LatLng origin,
    LatLng current,
    LatLng delta,
    String featureId,
    Annotation? annotation,
    DragEventType eventType,
  ) {
    // Find which waypoint is being dragged
    String? waypointId;
    for (final entry in _symbols.entries) {
      if (entry.value.id == featureId) {
        waypointId = entry.key;
        break;
      }
    }
    if (waypointId == null) return;

    switch (eventType) {
      case DragEventType.start:
        _draggingWaypointId = waypointId;
        widget.onDragStarted?.call();
        _initDragPreview(waypointId, current);
      case DragEventType.drag:
        _moveDragPreview(current);
      case DragEventType.end:
        _clearDragPreview();
        _draggingWaypointId = null;
        widget.onWaypointMoved(
            waypointId, current.latitude, current.longitude);
    }
  }

  Future<void> _initDragPreview(String waypointId, LatLng pos) async {
    final idx = widget.waypoints.indexWhere((w) => w.id == waypointId);
    if (idx < 0) return;

    if (idx > 0) {
      final prev = widget.waypoints[idx - 1];
      _dragLine1 = await widget.mapController.addLine(LineOptions(
        geometry: [LatLng(prev.latitude, prev.longitude), pos],
        lineColor: '#888888',
        lineWidth: 2.0,
        lineOpacity: 0.6,
      ));
    }
    if (idx < widget.waypoints.length - 1) {
      final next = widget.waypoints[idx + 1];
      _dragLine2 = await widget.mapController.addLine(LineOptions(
        geometry: [pos, LatLng(next.latitude, next.longitude)],
        lineColor: '#888888',
        lineWidth: 2.0,
        lineOpacity: 0.6,
      ));
    }
  }

  Future<void> _moveDragPreview(LatLng pos) async {
    if (_draggingWaypointId == null) return;
    final idx =
        widget.waypoints.indexWhere((w) => w.id == _draggingWaypointId);
    if (idx < 0) return;

    if (_dragLine1 != null && idx > 0) {
      final prev = widget.waypoints[idx - 1];
      await widget.mapController.updateLine(
        _dragLine1!,
        LineOptions(
            geometry: [LatLng(prev.latitude, prev.longitude), pos]),
      );
    }
    if (_dragLine2 != null && idx < widget.waypoints.length - 1) {
      final next = widget.waypoints[idx + 1];
      await widget.mapController.updateLine(
        _dragLine2!,
        LineOptions(geometry: [pos, LatLng(next.latitude, next.longitude)]),
      );
    }
  }

  Future<void> _clearDragPreview() async {
    if (_dragLine1 != null) {
      try {
        await widget.mapController.removeLine(_dragLine1!);
      } catch (_) {}
      _dragLine1 = null;
    }
    if (_dragLine2 != null) {
      try {
        await widget.mapController.removeLine(_dragLine2!);
      } catch (_) {}
      _dragLine2 = null;
    }
  }

  // ─── Symbol sync ──────────────────────────────────────────────────────────

  Future<void> _removeAllSymbols() async {
    for (final symbol in _symbols.values) {
      try {
        await widget.mapController.removeSymbol(symbol);
      } catch (_) {}
    }
    _symbols.clear();
    for (final symbol in _midpointSymbols.values) {
      try {
        await widget.mapController.removeSymbol(symbol);
      } catch (_) {}
    }
    _midpointSymbols.clear();
  }

  Future<void> _syncAll({bool forceImages = false}) async {
    if (forceImages || _registeredColor != widget.routeColor) {
      await _registerImages();
      _registeredColor = widget.routeColor;
    }

    // ── Waypoint symbols ──
    final current = {for (final wp in widget.waypoints) wp.id: wp};

    // Remove symbols for deleted waypoints
    for (final id in List<String>.from(_symbols.keys)) {
      if (!current.containsKey(id)) {
        try {
          await widget.mapController.removeSymbol(_symbols[id]!);
        } catch (_) {}
        _symbols.remove(id);
      }
    }

    final total = widget.waypoints.length;
    for (int i = 0; i < total; i++) {
      final wp = widget.waypoints[i];
      final isSelected = wp.id == widget.selectedWaypointId;
      final imageKey = _imageKey(i, total, isSelected);
      final position = LatLng(wp.latitude, wp.longitude);

      if (_symbols.containsKey(wp.id)) {
        await widget.mapController.updateSymbol(
          _symbols[wp.id]!,
          SymbolOptions(geometry: position, iconImage: imageKey),
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

    // ── Midpoint insert symbols ──
    await _syncMidpoints();
  }

  Future<void> _syncMidpoints() async {
    // Hide midpoints while dragging or when fewer than 2 waypoints
    if (_draggingWaypointId != null || widget.waypoints.length < 2) {
      for (final sym in List<Symbol>.from(_midpointSymbols.values)) {
        try {
          await widget.mapController.removeSymbol(sym);
        } catch (_) {}
      }
      _midpointSymbols.clear();
      return;
    }

    final segCount = widget.waypoints.length - 1;

    // Remove stale midpoint symbols (segments that no longer exist)
    for (final i in List<int>.from(_midpointSymbols.keys)) {
      if (i >= segCount) {
        try {
          await widget.mapController.removeSymbol(_midpointSymbols[i]!);
        } catch (_) {}
        _midpointSymbols.remove(i);
      }
    }

    // Add or update midpoint symbols for each segment
    for (int i = 0; i < segCount; i++) {
      final wp1 = widget.waypoints[i];
      final wp2 = widget.waypoints[i + 1];
      final midLat = (wp1.latitude + wp2.latitude) / 2;
      final midLon = (wp1.longitude + wp2.longitude) / 2;
      final pos = LatLng(midLat, midLon);

      if (_midpointSymbols.containsKey(i)) {
        await widget.mapController.updateSymbol(
          _midpointSymbols[i]!,
          SymbolOptions(geometry: pos),
        );
      } else {
        final sym = await widget.mapController.addSymbol(
          SymbolOptions(
            geometry: pos,
            iconImage: 'wp-midinsert',
            iconSize: 1.0,
            iconAnchor: 'center',
            draggable: false,
          ),
        );
        _midpointSymbols[i] = sym;
      }
    }
  }

  String _imageKey(int index, int total, bool selected) {
    final suffix = selected ? '-sel' : '';
    if (index == 0) return 'wp-start$suffix';
    if (index == total - 1 && total > 1) return 'wp-end$suffix';
    return 'wp-mid-${index + 1}$suffix';
  }

  // ─── Image registration ───────────────────────────────────────────────────

  Future<void> _registerImages() async {
    final borderColor = _hexToColor(widget.routeColor);
    const yellowBorder = Color(0xFFEAB308);

    // Start
    await _addImage('wp-start',
        await _makeCircle(fill: const Color(0xFF22C55E), border: borderColor, diameter: 28));
    await _addImage('wp-start-sel',
        await _makeCircle(fill: const Color(0xFF22C55E), border: yellowBorder, diameter: 28, borderWidth: 3));

    // End
    await _addImage('wp-end',
        await _makeCircle(fill: const Color(0xFFEF4444), border: borderColor, diameter: 28));
    await _addImage('wp-end-sel',
        await _makeCircle(fill: const Color(0xFFEF4444), border: yellowBorder, diameter: 28, borderWidth: 3));

    // Middle waypoints 1–30
    for (int i = 1; i <= 30; i++) {
      await _addImage('wp-mid-$i',
          await _makeCircle(fill: Colors.white, border: borderColor, diameter: 24, label: '$i', labelColor: Colors.black87));
      await _addImage('wp-mid-$i-sel',
          await _makeCircle(fill: Colors.white, border: yellowBorder, diameter: 24, borderWidth: 3, label: '$i', labelColor: Colors.black87));
    }

    // Midpoint insert dot — solid route-color circle, small, no label
    await _addImage('wp-midinsert',
        await _makeCircle(fill: borderColor, border: borderColor, diameter: 14));
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

    // Shadow
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
    canvas.drawCircle(Offset(r, r), r - borderWidth, Paint()..color = fill);

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
