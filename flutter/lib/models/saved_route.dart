import 'dart:convert';
import 'waypoint.dart';
import 'route_stats.dart';

class SavedRoute {
  final int id;
  final String? remoteId;
  final String name;
  final String color;
  final List<Waypoint> waypoints;
  final Map<String, dynamic> geometry; // GeoJSON LineString Feature
  final RouteStats? stats;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  const SavedRoute({
    required this.id,
    this.remoteId,
    required this.name,
    required this.color,
    required this.waypoints,
    required this.geometry,
    this.stats,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory SavedRoute.fromDb(Map<String, dynamic> row) => SavedRoute(
        id: row['id'] as int,
        remoteId: row['remote_id'] as String?,
        name: row['name'] as String,
        color: row['color'] as String? ?? '#3b82f6',
        waypoints: (jsonDecode(row['waypoints'] as String) as List)
            .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        geometry:
            jsonDecode(row['geometry'] as String) as Map<String, dynamic>,
        stats: row['stats'] != null
            ? RouteStats.fromJson(
                jsonDecode(row['stats'] as String) as Map<String, dynamic>)
            : null,
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
        deletedAt: row['deleted_at'] as String?,
      );
}
