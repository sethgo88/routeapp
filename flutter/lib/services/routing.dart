import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/map.dart';
import '../models/waypoint.dart';
import '../models/route_stats.dart';

class RouteResult {
  final Map<String, dynamic> geometry; // GeoJSON LineString Feature
  final List<List<double>> elevationData; // [[distanceKm, elevationM], ...]
  final RouteStats stats;

  const RouteResult({
    required this.geometry,
    required this.elevationData,
    required this.stats,
  });
}

/// Decodes a Valhalla polyline6-encoded string into [lon, lat] pairs.
/// Valhalla uses precision 1e6 (NOT standard Google 1e5) and returns [lat, lon].
List<List<double>> decodePolyline6(String encoded) {
  if (encoded.isEmpty) return [];
  final coords = <List<double>>[];
  int index = 0;
  int lat = 0;
  int lon = 0;

  while (index < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    lat += dLat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLon = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    lon += dLon;

    coords.add([lon / 1e6, lat / 1e6]); // GeoJSON is [lon, lat]
  }
  return coords;
}

Map<String, dynamic> _buildRouteRequest(
  List<Waypoint> waypoints,
  double useTrails,
) {
  return {
    'locations': waypoints
        .map((wp) => {'lon': wp.longitude, 'lat': wp.latitude, 'type': 'break'})
        .toList(),
    'costing': 'pedestrian',
    'costing_options': {
      'pedestrian': {'use_trails': useTrails, 'walking_speed': 5.1},
    },
    'directions_type': 'none',
  };
}

Future<List<List<double>>> _fetchRouteShape(
  Waypoint from,
  Waypoint to,
) async {
  final url = Uri.parse(
    stadiaApiKey.isNotEmpty
        ? '$valhallaBaseUrl/route/v1?api_key=$stadiaApiKey'
        : '$valhallaBaseUrl/route/v1',
  );
  final body = {
    'locations': [
      {'lon': from.longitude, 'lat': from.latitude, 'type': 'break'},
      {'lon': to.longitude, 'lat': to.latitude, 'type': 'break'},
    ],
    'costing': 'pedestrian',
    'costing_options': {
      'pedestrian': {'use_trails': 1.0, 'walking_speed': 5.1},
    },
    'directions_type': 'none',
  };

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (response.statusCode != 200) {
    throw Exception('Valhalla route error ${response.statusCode}: ${response.body}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final legs = (data['trip']['legs'] as List).cast<Map<String, dynamic>>();
  final coords = <List<double>>[];
  for (final leg in legs) {
    final legCoords = decodePolyline6(leg['shape'] as String);
    coords.addAll(coords.isEmpty ? legCoords : legCoords.skip(1));
  }
  return coords;
}

Future<({List<List<double>> rangeHeight, List<double> heights})>
    _fetchElevation(List<List<double>> coords) async {
  final url = Uri.parse(
    stadiaApiKey.isNotEmpty
        ? '$valhallaBaseUrl/elevation/v1?api_key=$stadiaApiKey'
        : '$valhallaBaseUrl/elevation/v1',
  );
  final body = {
    'shape': coords.map((c) => {'lon': c[0], 'lat': c[1]}).toList(),
    'range': true,
  };

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (response.statusCode != 200) {
    throw Exception('Elevation error ${response.statusCode}: ${response.body}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final raw = (data['range_height'] as List)
      .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
      .toList();
  return (
    rangeHeight: raw,
    heights: raw.map((e) => e[1]).toList(),
  );
}

({double gainM, double lossM}) _calcGainLoss(List<double> heights) {
  double gainM = 0, lossM = 0;
  for (int i = 1; i < heights.length; i++) {
    final diff = heights[i] - heights[i - 1];
    if (diff > 0) {
      gainM += diff;
    } else {
      lossM += -diff;
    }
  }
  return (gainM: gainM, lossM: lossM);
}

/// Fetch route for all waypoints with a single global snap setting.
Future<RouteResult> fetchRoute(
  List<Waypoint> waypoints,
  bool snapToTrails,
) async {
  final url = Uri.parse(
    stadiaApiKey.isNotEmpty
        ? '$valhallaBaseUrl/route/v1?api_key=$stadiaApiKey'
        : '$valhallaBaseUrl/route/v1',
  );
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(_buildRouteRequest(waypoints, snapToTrails ? 1.0 : 0.5)),
  );
  if (response.statusCode != 200) {
    throw Exception('Valhalla route error ${response.statusCode}: ${response.body}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final trip = data['trip'] as Map<String, dynamic>;
  final legs = (trip['legs'] as List).cast<Map<String, dynamic>>();
  final distanceKm = (trip['summary']['length'] as num).toDouble();

  final coords = <List<double>>[];
  for (final leg in legs) {
    final legCoords = decodePolyline6(leg['shape'] as String);
    coords.addAll(coords.isEmpty ? legCoords : legCoords.skip(1));
  }

  final elevation = await _fetchElevation(coords);
  final gainLoss = _calcGainLoss(elevation.heights);

  return RouteResult(
    geometry: {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coords,
      },
      'properties': {},
    },
    elevationData: elevation.rangeHeight
        .map((e) => [e[0] / 1000, e[1]])
        .toList(),
    stats: RouteStats(
      distanceKm: distanceKm,
      gainM: gainLoss.gainM,
      lossM: gainLoss.lossM,
    ),
  );
}

/// Fetch route with per-waypoint snap settings (segmented mode).
Future<RouteResult> fetchRouteSegmented(List<Waypoint> waypoints) async {
  final allCoords = <List<double>>[];

  for (int i = 0; i < waypoints.length - 1; i++) {
    final from = waypoints[i];
    final to = waypoints[i + 1];
    List<List<double>> segCoords;

    if (to.snapAfter) {
      segCoords = await _fetchRouteShape(from, to);
    } else {
      segCoords = [
        [from.longitude, from.latitude],
        [to.longitude, to.latitude],
      ];
    }
    allCoords.addAll(allCoords.isEmpty ? segCoords : segCoords.skip(1));
  }

  final elevation = await _fetchElevation(allCoords);
  final gainLoss = _calcGainLoss(elevation.heights);
  final distanceKm = elevation.rangeHeight.isNotEmpty
      ? elevation.rangeHeight.last[0] / 1000
      : 0.0;

  return RouteResult(
    geometry: {
      'type': 'Feature',
      'geometry': {'type': 'LineString', 'coordinates': allCoords},
      'properties': {},
    },
    elevationData: elevation.rangeHeight
        .map((e) => [e[0] / 1000, e[1]])
        .toList(),
    stats: RouteStats(
      distanceKm: distanceKm,
      gainM: gainLoss.gainM,
      lossM: gainLoss.lossM,
    ),
  );
}
