import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/waypoint.dart';
import '../models/route_stats.dart';
import '../constants/map.dart';
import '../services/db.dart' as db;
import 'route_state.dart';

class RouteNotifier extends Notifier<RouteState> {
  @override
  RouteState build() => const RouteState();

  String _makeId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${state.waypoints.length}';

  void setEditingMode(EditingMode mode) =>
      state = state.copyWith(editingMode: mode);

  void addWaypoint(double lat, double lon) {
    final newWp = Waypoint(
      id: _makeId(),
      latitude: lat,
      longitude: lon,
      label: waypointLabel(state.waypoints.length),
      snapAfter: state.isSnapping,
    );
    state = state.copyWith(
      history: [...state.history, state.waypoints],
      future: [],
      waypoints: [...state.waypoints, newWp],
    );
  }

  void moveWaypoint(String id, double lat, double lon) {
    state = state.copyWith(
      history: [...state.history, state.waypoints],
      future: [],
      waypoints: state.waypoints
          .map((wp) => wp.id == id ? wp.copyWith(latitude: lat, longitude: lon) : wp)
          .toList(),
    );
  }

  void removeWaypoint(String id) {
    final newWaypoints = state.waypoints.where((wp) => wp.id != id).toList();
    final relabeled = newWaypoints
        .asMap()
        .entries
        .map((e) => e.value.copyWith(label: waypointLabel(e.key)))
        .toList();
    state = state.copyWith(
      history: [...state.history, state.waypoints],
      future: [],
      waypoints: relabeled,
    );
  }

  void undo() {
    if (state.history.isEmpty) return;
    final previous = state.history.last;
    state = state.copyWith(
      waypoints: previous,
      history: state.history.sublist(0, state.history.length - 1),
      future: [state.waypoints, ...state.future],
    );
  }

  void redo() {
    if (state.future.isEmpty) return;
    final next = state.future.first;
    state = state.copyWith(
      waypoints: next,
      history: [...state.history, state.waypoints],
      future: state.future.sublist(1),
    );
  }

  bool get canUndo => state.history.isNotEmpty;
  bool get canRedo => state.future.isNotEmpty;

  void setRoute(Map<String, dynamic>? route) => route != null
      ? state = state.copyWith(route: route)
      : state = state.copyWith(clearRoute: true);

  void setElevationData(List<List<double>> data) =>
      state = state.copyWith(elevationData: data);

  void setRouteStats(RouteStats? stats) => stats != null
      ? state = state.copyWith(routeStats: stats)
      : state = state.copyWith(clearStats: true);

  void setIsSnapping(bool value) => state = state.copyWith(isSnapping: value);

  void setIsLoading(bool value) => state = state.copyWith(isLoading: value);

  void setFocusCoordinate(List<double>? coord) => coord != null
      ? state = state.copyWith(focusCoordinate: coord)
      : state = state.copyWith(clearFocus: true);

  void setElevationMarkerCoord(List<double>? coord) => coord != null
      ? state = state.copyWith(elevationMarkerCoord: coord)
      : state = state.copyWith(clearElevationMarker: true);

  void setRouteColor(String color) => state = state.copyWith(routeColor: color);

  void setEditingRouteName(String name) =>
      state = state.copyWith(editingRouteName: name);

  void clearAll() {
    state = RouteState(isSnapping: state.isSnapping);
  }

  void loadWaypoints(List<Waypoint> coords) {
    state = state.copyWith(
      waypoints: coords,
      clearRoute: true,
      elevationData: [],
      clearStats: true,
    );
  }

  Future<void> loadRouteForEditing(int id) async {
    final saved = await db.getRoute(id);
    if (saved == null) return;
    state = RouteState(
      editingMode: EditingMode.editing,
      activeRouteId: id,
      waypoints: saved.waypoints,
      route: saved.geometry,
      routeStats: saved.stats,
      routeColor: saved.color,
      editingRouteName: saved.name,
      isSnapping: state.isSnapping,
    );
  }
}

final routeProvider =
    NotifierProvider<RouteNotifier, RouteState>(RouteNotifier.new);
