import 'package:maplibre_gl/maplibre_gl.dart';

/// Lightweight wrapper around [OfflineRegion] with a resolved name and size.
class OfflineRegionInfo {
  final int id;
  final String name;
  final LatLngBounds bounds;
  final String styleUrl;
  final double minZoom;
  final double maxZoom;
  final double estimatedSizeMB;

  const OfflineRegionInfo({
    required this.id,
    required this.name,
    required this.bounds,
    required this.styleUrl,
    required this.minZoom,
    required this.maxZoom,
    required this.estimatedSizeMB,
  });

  factory OfflineRegionInfo.fromOfflineRegion(OfflineRegion region) {
    final def = region.definition;
    final meta = region.metadata;
    return OfflineRegionInfo(
      id: region.id,
      name: (meta['name'] as String?)?.isNotEmpty == true
          ? meta['name'] as String
          : 'Unnamed region',
      bounds: def.bounds,
      styleUrl: def.mapStyleUrl,
      minZoom: def.minZoom,
      maxZoom: def.maxZoom,
      estimatedSizeMB:
          (meta['estimatedSizeMB'] as num?)?.toDouble() ?? 0,
    );
  }

  String get formattedSize {
    if (estimatedSizeMB < 1) return '< 1 MB';
    return '${estimatedSizeMB.toStringAsFixed(1)} MB';
  }
}
