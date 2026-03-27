import 'package:xml/xml.dart';
import '../../models/waypoint.dart';
import '../../constants/map.dart';

/// Parses a GPX 1.1 string and returns a list of Coordinates as Waypoints.
/// Only track points (<trkpt>) are used; waypoints and routes are ignored.
List<Waypoint> parseGpx(String gpxString) {
  final document = XmlDocument.parse(gpxString);
  final trkpts = document.findAllElements('trkpt');
  final waypoints = <Waypoint>[];

  for (final trkpt in trkpts) {
    final lat = double.tryParse(trkpt.getAttribute('lat') ?? '');
    final lon = double.tryParse(trkpt.getAttribute('lon') ?? '');
    if (lat == null || lon == null) continue;

    waypoints.add(Waypoint(
      id: '${DateTime.now().microsecondsSinceEpoch}-${waypoints.length}',
      latitude: lat,
      longitude: lon,
      label: waypointLabel(waypoints.length),
      snapAfter: false, // imported points use straight lines; user can re-route
    ));
  }

  return waypoints;
}
