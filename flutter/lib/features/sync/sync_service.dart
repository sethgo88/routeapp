import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/db.dart' as db;

/// Cloud sync service. Triggers on sign-in or manual call.
///
/// Strategy (local-first):
///  1. Push  — upsert all local routes (incl. deleted) to Supabase.
///             Store returned UUID as remote_id on first push.
///  2. Pull  — fetch all user's routes from Supabase.
///             Insert any whose remote_id is not yet in local DB.
///  3. Settings — upsert unit_system to user_settings table.
class SyncService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Returns [true] if sync completed successfully, [false] if unreachable or failed.
  Future<bool> sync() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _push(user.id);
      await _pull(user.id);
      await _syncSettings(user.id);
      return true;
    } catch (e) {
      // Sync is best-effort; don't crash the app on failure.
      // ignore: avoid_print
      print('Sync error: $e');
      return false;
    }
  }

  Future<void> _push(String userId) async {
    final routes = await db.listRoutesAll();
    for (final route in routes) {
      final data = <String, dynamic>{
        'user_id': userId,
        'name': route.name,
        'color': route.color,
        'waypoints': route.waypoints.map((w) => w.toJson()).toList(),
        'geometry': route.geometry,
        'stats': route.stats?.toJson(),
        'created_at': route.createdAt,
        'updated_at': route.updatedAt,
        'deleted_at': route.deletedAt,
      };

      if (route.remoteId != null) {
        data['id'] = route.remoteId;
      }

      final response = await _client
          .from('routes')
          .upsert(data)
          .select('id')
          .single();

      if (route.remoteId == null) {
        final newRemoteId = response['id'] as String?;
        if (newRemoteId != null) {
          await db.setRemoteId(route.id, newRemoteId);
        }
      }
    }
  }

  Future<void> _pull(String userId) async {
    final List<dynamic> remoteRoutes = await _client
        .from('routes')
        .select()
        .eq('user_id', userId);

    for (final dynamic rawRow in remoteRoutes) {
      final row = rawRow as Map<String, dynamic>;
      final remoteId = row['id'] as String;
      final existing = await db.getRouteByRemoteId(remoteId);
      if (existing != null) continue;

      // Insert pulled route locally.
      await db.insertFromRemote(
        remoteId: remoteId,
        name: row['name'] as String,
        color: row['color'] as String? ?? '#3b82f6',
        waypointsJson: jsonEncode(row['waypoints']),
        geometryJson: jsonEncode(row['geometry']),
        statsJson: row['stats'] != null ? jsonEncode(row['stats']) : null,
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
        deletedAt: row['deleted_at'] as String?,
      );
    }
  }

  Future<void> _syncSettings(String userId) async {
    final localUnit = await db.getSetting('unit_system');
    if (localUnit != null) {
      await _client.from('user_settings').upsert({
        'user_id': userId,
        'key': 'unit_system',
        'value': localUnit,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}

final syncService = SyncService();
