import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/map_layers.dart';
import '../../state/settings_provider.dart';
import '../map/layer_popover.dart';

/// Full-screen map with a draggable bounding-box rectangle.
/// Pops with `true` when the region is successfully downloaded.
class BboxSelectionScreen extends ConsumerStatefulWidget {
  const BboxSelectionScreen({super.key});

  @override
  ConsumerState<BboxSelectionScreen> createState() =>
      _BboxSelectionScreenState();
}

class _BboxSelectionScreenState
    extends ConsumerState<BboxSelectionScreen> {
  // ── Map state ─────────────────────────────────────────────────────────────
  MaplibreMapController? _mapController;
  bool _mapStyleLoaded = false;
  bool _showLayerPopover = false;

  // ── Bbox in screen coordinates (set once layout is known) ─────────────────
  double _left = 0, _top = 0, _right = 0, _bottom = 0;
  bool _bboxInitialized = false;

  // ── Drag state ────────────────────────────────────────────────────────────
  int? _draggingCorner; // 0=TL 1=TR 2=BL 3=BR
  late List<Offset> _dragStartCorners; // corner positions at long-press start

  // ── Download state ────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  double _estimatedSizeMB = 0;
  double _downloadProgress = 0; // 0.0 – 1.0
  bool _downloading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _dragStartCorners = List.filled(4, Offset.zero);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  MapLayer get _activeLayer =>
      ref.read(activeLayerProvider) ??
      ref.read(settingsProvider).value?.defaultLayer ??
      MapLayer.trail;

  void _initBbox(Size size) {
    if (_bboxInitialized) return;
    _bboxInitialized = true;
    // Start rect: centred, ~60 % width, leaving room for bottom bar.
    const hPad = 60.0;
    const vPad = 80.0;
    const bottomBarHeight = 110.0;
    _left = hPad;
    _right = size.width - hPad;
    _top = vPad;
    _bottom = size.height - bottomBarHeight - vPad;
  }

  List<Offset> get _corners => [
        Offset(_left, _top),     // 0: TL
        Offset(_right, _top),    // 1: TR
        Offset(_left, _bottom),  // 2: BL
        Offset(_right, _bottom), // 3: BR
      ];

  void _updateCorner(int i, double x, double y) {
    switch (i) {
      case 0:
        _left = x;
        _top = y;
      case 1:
        _right = x;
        _top = y;
      case 2:
        _left = x;
        _bottom = y;
      case 3:
        _right = x;
        _bottom = y;
    }
    // Keep rectangle valid (prevent corners crossing).
    if (_left > _right - 20) _left = _right - 20;
    if (_top > _bottom - 20) _top = _bottom - 20;
  }

  double _estimateSizeMB(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) {
    const minZ = 5;
    const maxZ = 14;
    const bytesPerTile = 15 * 1024; // rough: 15 KB per vector tile
    double totalTiles = 0;
    final latSpan = (maxLat - minLat).abs();
    final lonSpan = (maxLon - minLon).abs();
    for (int z = minZ; z <= maxZ; z++) {
      final tilesAtZoom = pow(2.0, z);
      final latT = max(1, (latSpan / 180 * tilesAtZoom).ceil());
      final lonT = max(1, (lonSpan / 360 * tilesAtZoom).ceil());
      totalTiles += latT * lonT;
    }
    return totalTiles * bytesPerTile / (1024 * 1024);
  }

  String _formatSize(double mb) {
    if (mb < 1) return '< 1 MB';
    if (mb < 1000) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _updateSizeEstimate() async {
    final ctrl = _mapController;
    if (ctrl == null || !_mapStyleLoaded) return;
    try {
      // SW = bottom-left, NE = top-right in screen space.
      final sw = await ctrl.toLatLng(Point<double>(_left, _bottom));
      final ne = await ctrl.toLatLng(Point<double>(_right, _top));
      final mb = _estimateSizeMB(
          sw.latitude, sw.longitude, ne.latitude, ne.longitude);
      if (mounted) setState(() => _estimatedSizeMB = mb);
    } catch (_) {}
  }

  Future<void> _centerOnLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(pos.latitude, pos.longitude),
        12,
      ),
    );
  }

  void _onLayerSelected(MapLayer layer) {
    setState(() => _showLayerPopover = false);
    ref.read(activeLayerProvider.notifier).set(layer);
    ref.read(settingsProvider.notifier).setDefaultLayer(layer);
    setState(() => _mapStyleLoaded = false);
    _mapController?.setStyle(layer.styleUrl);
  }

  Future<void> _download() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a region name')),
      );
      return;
    }
    final ctrl = _mapController;
    if (ctrl == null) return;

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      final sw = await ctrl.toLatLng(Point<double>(_left, _bottom));
      final ne = await ctrl.toLatLng(Point<double>(_right, _top));

      await downloadOfflineRegion(
        OfflineRegionDefinition(
          bounds: LatLngBounds(southwest: sw, northeast: ne),
          mapStyleUrl: _activeLayer.styleUrl,
          minZoom: 5,
          maxZoom: 14,
        ),
        metadata: {
          'name': name,
          'estimatedSizeMB': _estimatedSizeMB,
        },
        onEvent: (DownloadRegionStatus status) {
          if (!mounted) return;
          if (status is InProgress) {
            setState(() => _downloadProgress = status.progress);
          } else if (status is Error) {
            setState(() => _downloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download error: ${status.cause}')),
            );
          } else if (status is Success) {
            // Navigator.pop called below after await returns.
          }
        },
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_isDirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave?'),
        content: const Text(
            'Are you sure you want to leave? All information will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Sync map style when active layer changes externally.
    ref.listen<MapLayer?>(activeLayerProvider, (prev, next) {
      if (next != null && prev != next && _mapController != null) {
        setState(() => _mapStyleLoaded = false);
        _mapController!.setStyle(next.styleUrl);
      }
    });

    final activeLayer = ref.watch(activeLayerProvider) ??
        ref.watch(settingsProvider).value?.defaultLayer ??
        MapLayer.trail;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _isDirty) {
          final leave = await _confirmLeave();
          if (leave && mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size =
                Size(constraints.maxWidth, constraints.maxHeight);
            _initBbox(size);

            return Stack(
              children: [
                // ── Full-screen map ────────────────────────────────────────
                MaplibreMap(
                  styleString: activeLayer.styleUrl,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(37.7749, -122.4194),
                    zoom: 10,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onStyleLoadedCallback: () {
                    setState(() => _mapStyleLoaded = true);
                    _updateSizeEstimate();
                  },
                  scrollGesturesEnabled: _draggingCorner == null,
                  zoomGesturesEnabled: _draggingCorner == null,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationEnabled: false,
                ),

                // ── Bbox rectangle (drawn behind corner dots) ──────────────
                if (_bboxInitialized)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BboxPainter(
                          left: _left,
                          top: _top,
                          right: _right,
                          bottom: _bottom,
                        ),
                      ),
                    ),
                  ),

                // ── Draggable corner dots ──────────────────────────────────
                if (_bboxInitialized) ..._buildCornerDots(),

                // ── Top controls ───────────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button
                        _MapIconButton(
                          icon: Icons.chevron_left,
                          label: 'back',
                          onPressed: () async {
                            if (await _confirmLeave()) {
                              if (mounted) Navigator.of(context).pop();
                            }
                          },
                        ),
                        const Spacer(),
                        // Layers
                        _MapIconButton(
                          icon: Icons.layers,
                          highlighted: _showLayerPopover,
                          onPressed: () => setState(
                              () => _showLayerPopover = !_showLayerPopover),
                        ),
                        const SizedBox(width: 8),
                        // GPS
                        _MapIconButton(
                          icon: Icons.my_location,
                          onPressed: _centerOnLocation,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Layer popover tap-outside dismissal ────────────────────
                if (_showLayerPopover)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showLayerPopover = false),
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),

                // ── Layer popover widget ───────────────────────────────────
                if (_showLayerPopover)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 52, right: 54),
                        child: LayerPopover(
                          activeLayer: activeLayer,
                          onLayerSelected: _onLayerSelected,
                        ),
                      ),
                    ),
                  ),

                // ── Bottom bar ─────────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Size estimate
                            Text(
                              'Estimated download size: ${_formatSize(_estimatedSizeMB)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            // Name + Save row
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nameController,
                                    enabled: !_downloading,
                                    decoration: const InputDecoration(
                                      hintText: 'Region name',
                                      border: OutlineInputBorder(),
                                      contentPadding:
                                          EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      if (!_isDirty && v.isNotEmpty) {
                                        setState(() => _isDirty = true);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _downloading ? null : _download,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF3b82f6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                  child: _downloading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Save'),
                                ),
                              ],
                            ),
                            // Download progress bar
                            if (_downloading)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _downloadProgress > 0
                                        ? _downloadProgress
                                        : null,
                                    backgroundColor: Colors.grey.shade200,
                                    color: const Color(0xFF3b82f6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Corner dots ────────────────────────────────────────────────────────────

  List<Widget> _buildCornerDots() {
    const dotSize = 24.0;
    final corners = _corners;
    return List.generate(4, (i) {
      final pos = corners[i];
      return Positioned(
        left: pos.dx - dotSize / 2,
        top: pos.dy - dotSize / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) {
            setState(() {
              _draggingCorner = i;
              _dragStartCorners = List.of(_corners);
              _isDirty = true;
            });
          },
          onLongPressMoveUpdate: (details) {
            setState(() {
              final start = _dragStartCorners[i];
              _updateCorner(
                i,
                start.dx + details.offsetFromOrigin.dx,
                start.dy + details.offsetFromOrigin.dy,
              );
            });
          },
          onLongPressEnd: (_) {
            setState(() => _draggingCorner = null);
            _updateSizeEstimate();
          },
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: const Color(0xFF3b82f6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── Bbox painter ──────────────────────────────────────────────────────────────

class _BboxPainter extends CustomPainter {
  final double left, top, right, bottom;

  const _BboxPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(left, top, right, bottom);

    // Transparent fill
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF3b82f6).withAlpha(38) // ~15 % opacity
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF3b82f6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_BboxPainter old) =>
      old.left != left ||
      old.top != top ||
      old.right != right ||
      old.bottom != bottom;
}

// ── Shared icon button (local to this screen) ─────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool highlighted;

  const _MapIconButton({
    required this.icon,
    this.label,
    this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = label != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20,
                  color: highlighted ? Colors.white : Colors.black87),
              const SizedBox(width: 2),
              Text(label!,
                  style: TextStyle(
                      color: highlighted ? Colors.white : Colors.black87)),
            ],
          )
        : Icon(icon, size: 22,
            color: highlighted ? Colors.white : Colors.black87);

    return Material(
      color: highlighted ? const Color(0xFF3b82f6) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: child,
        ),
      ),
    );
  }
}
