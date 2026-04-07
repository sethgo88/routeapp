import '../../models/saved_route.dart';

/// Generates a GPX 1.1 string with one &lt;trk&gt; per route.
/// Routes with null geometry are skipped.
String exportAllGpx(List<SavedRoute> routes) {
  final now = DateTime.now().toUtc().toIso8601String();
  final buffer = StringBuffer();

  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
      '<gpx version="1.1" creator="routeapp" xmlns="http://www.topografix.com/GPX/1/1">');
  buffer.writeln('  <metadata>');
  buffer.writeln('    <name>All Routes</name>');
  buffer.writeln('    <time>$now</time>');
  buffer.writeln('  </metadata>');

  for (final route in routes) {
    final coordinates =
        (route.geometry['geometry']['coordinates'] as List)
            .map((c) => (c as List).map((v) => (v as num).toDouble()).toList())
            .toList();
    if (coordinates.isEmpty) continue;

    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    buffer.writeln('    <trkseg>');
    for (final c in coordinates) {
      final lon = c[0];
      final lat = c[1];
      buffer.writeln('      <trkpt lat="$lat" lon="$lon"/>');
    }
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
  }

  buffer.writeln('</gpx>');
  return buffer.toString();
}

/// Generates a GPX 1.1 string from a GeoJSON LineString geometry and elevation data.
/// [geometry] — GeoJSON Feature with LineString geometry (coordinates are [lon, lat])
/// [elevationData] — [[distanceKm, elevationM], ...] parallel to shape points
/// [name] — route name written into the GPX metadata and track name
String exportGpx({
  required Map<String, dynamic> geometry,
  required List<List<double>> elevationData,
  required String name,
}) {
  final coordinates = (geometry['geometry']['coordinates'] as List)
      .map((c) => (c as List).map((v) => (v as num).toDouble()).toList())
      .toList();

  final now = DateTime.now().toUtc().toIso8601String();
  final buffer = StringBuffer();

  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln(
      '<gpx version="1.1" creator="routeapp" xmlns="http://www.topografix.com/GPX/1/1">');
  buffer.writeln('  <metadata>');
  buffer.writeln('    <name>${_escapeXml(name)}</name>');
  buffer.writeln('    <time>$now</time>');
  buffer.writeln('  </metadata>');
  buffer.writeln('  <trk>');
  buffer.writeln('    <name>${_escapeXml(name)}</name>');
  buffer.writeln('    <trkseg>');

  for (int i = 0; i < coordinates.length; i++) {
    final c = coordinates[i];
    final lon = c[0];
    final lat = c[1];
    buffer.write('      <trkpt lat="$lat" lon="$lon">');
    if (i < elevationData.length) {
      buffer.write('<ele>${elevationData[i][1].toStringAsFixed(1)}</ele>');
    }
    buffer.writeln('</trkpt>');
  }

  buffer.writeln('    </trkseg>');
  buffer.writeln('  </trk>');
  buffer.writeln('</gpx>');

  return buffer.toString();
}

String _escapeXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
