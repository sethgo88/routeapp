import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/waypoint.dart';
import '../models/route_stats.dart';
import '../models/saved_route.dart';

Database? _db;

Future<Database> getDb() async {
  _db ??= await openDatabase(
    join(await getDatabasesPath(), 'routes.db'),
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE routes (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id   TEXT,
          name        TEXT    NOT NULL,
          color       TEXT    NOT NULL DEFAULT '#3b82f6',
          waypoints   TEXT    NOT NULL,
          geometry    TEXT    NOT NULL,
          stats       TEXT,
          created_at  TEXT    NOT NULL,
          updated_at  TEXT    NOT NULL,
          deleted_at  TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE settings (
          key         TEXT PRIMARY KEY,
          value       TEXT NOT NULL,
          updated_at  TEXT NOT NULL
        )
      ''');
      await db.insert('settings', {
        'key': 'unit_system',
        'value': 'metric',
        'updated_at': DateTime.now().toIso8601String(),
      });
    },
  );
  return _db!;
}

// ── Read ─────────────────────────────────────────────────────────────────────

Future<List<SavedRoute>> listRoutes() async {
  final db = await getDb();
  final rows = await db.query(
    'routes',
    where: 'deleted_at IS NULL',
    orderBy: 'created_at DESC',
  );
  return rows.map(SavedRoute.fromDb).toList();
}

/// Returns ALL routes including soft-deleted ones (for sync push).
Future<List<SavedRoute>> listRoutesAll() async {
  final db = await getDb();
  final rows = await db.query('routes', orderBy: 'created_at DESC');
  return rows.map(SavedRoute.fromDb).toList();
}

Future<SavedRoute?> getRoute(int id) async {
  final db = await getDb();
  final rows = await db.query(
    'routes',
    where: 'id = ? AND deleted_at IS NULL',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return SavedRoute.fromDb(rows.first);
}

Future<SavedRoute?> getRouteByRemoteId(String remoteId) async {
  final db = await getDb();
  final rows = await db.query(
    'routes',
    where: 'remote_id = ?',
    whereArgs: [remoteId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return SavedRoute.fromDb(rows.first);
}

// ── Write ────────────────────────────────────────────────────────────────────

Future<int> saveRoute({
  required String name,
  required String color,
  required List<Waypoint> waypoints,
  required Map<String, dynamic> geometry,
  RouteStats? stats,
}) async {
  final db = await getDb();
  final now = DateTime.now().toIso8601String();
  return db.insert('routes', {
    'name': name,
    'color': color,
    'waypoints': jsonEncode(waypoints.map((w) => w.toJson()).toList()),
    'geometry': jsonEncode(geometry),
    'stats': stats != null ? jsonEncode(stats.toJson()) : null,
    'created_at': now,
    'updated_at': now,
  });
}

Future<void> updateRoute({
  required int id,
  required String name,
  required String color,
  required List<Waypoint> waypoints,
  required Map<String, dynamic> geometry,
  RouteStats? stats,
}) async {
  final db = await getDb();
  await db.update(
    'routes',
    {
      'name': name,
      'color': color,
      'waypoints': jsonEncode(waypoints.map((w) => w.toJson()).toList()),
      'geometry': jsonEncode(geometry),
      'stats': stats != null ? jsonEncode(stats.toJson()) : null,
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<String?> deleteRoute(int id) async {
  final db = await getDb();
  final rows = await db.query(
    'routes',
    columns: ['remote_id'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  final remoteId = rows.isEmpty ? null : rows.first['remote_id'] as String?;
  final now = DateTime.now().toIso8601String();
  await db.update(
    'routes',
    {'deleted_at': now, 'updated_at': now},
    where: 'id = ?',
    whereArgs: [id],
  );
  return remoteId;
}

/// Set the remote_id for a route after a successful Supabase push.
Future<void> setRemoteId(int localId, String remoteId) async {
  final db = await getDb();
  await db.update(
    'routes',
    {'remote_id': remoteId},
    where: 'id = ?',
    whereArgs: [localId],
  );
}

/// Insert a route pulled from Supabase that does not yet exist locally.
Future<void> insertFromRemote({
  required String remoteId,
  required String name,
  required String color,
  required String waypointsJson,
  required String geometryJson,
  String? statsJson,
  required String createdAt,
  required String updatedAt,
  String? deletedAt,
}) async {
  final db = await getDb();
  await db.insert(
    'routes',
    {
      'remote_id': remoteId,
      'name': name,
      'color': color,
      'waypoints': waypointsJson,
      'geometry': geometryJson,
      'stats': statsJson,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}

// ── Settings ─────────────────────────────────────────────────────────────────

Future<String?> getSetting(String key) async {
  final db = await getDb();
  final rows = await db.query(
    'settings',
    columns: ['value'],
    where: 'key = ?',
    whereArgs: [key],
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first['value'] as String;
}

Future<void> setSetting(String key, String value) async {
  final db = await getDb();
  await db.insert(
    'settings',
    {'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
