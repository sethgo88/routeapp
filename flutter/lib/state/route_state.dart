import '../models/waypoint.dart';
import '../models/route_stats.dart';
import '../constants/map.dart';

enum EditingMode { view, creating, editing }

class RouteState {
  final EditingMode editingMode;
  final List<Waypoint> waypoints;
  final List<List<Waypoint>> history;
  final List<List<Waypoint>> future;
  final Map<String, dynamic>? route; // GeoJSON Feature or null
  final List<List<double>> elevationData; // [[distanceKm, elevM], ...]
  final RouteStats? routeStats;
  final bool isSnapping;
  final bool isLoading;
  final List<double>? focusCoordinate; // [lon, lat] for elevation tap-to-fly
  final List<double>? elevationMarkerCoord;
  final int? activeRouteId;
  final String routeColor;
  final String editingRouteName;

  const RouteState({
    this.editingMode = EditingMode.view,
    this.waypoints = const [],
    this.history = const [],
    this.future = const [],
    this.route,
    this.elevationData = const [],
    this.routeStats,
    this.isSnapping = true,
    this.isLoading = false,
    this.focusCoordinate,
    this.elevationMarkerCoord,
    this.activeRouteId,
    this.routeColor = defaultRouteColor,
    this.editingRouteName = '',
  });

  RouteState copyWith({
    EditingMode? editingMode,
    List<Waypoint>? waypoints,
    List<List<Waypoint>>? history,
    List<List<Waypoint>>? future,
    Map<String, dynamic>? route,
    bool clearRoute = false,
    List<List<double>>? elevationData,
    RouteStats? routeStats,
    bool clearStats = false,
    bool? isSnapping,
    bool? isLoading,
    List<double>? focusCoordinate,
    bool clearFocus = false,
    List<double>? elevationMarkerCoord,
    bool clearElevationMarker = false,
    int? activeRouteId,
    bool clearActiveRoute = false,
    String? routeColor,
    String? editingRouteName,
  }) {
    return RouteState(
      editingMode: editingMode ?? this.editingMode,
      waypoints: waypoints ?? this.waypoints,
      history: history ?? this.history,
      future: future ?? this.future,
      route: clearRoute ? null : (route ?? this.route),
      elevationData: elevationData ?? this.elevationData,
      routeStats: clearStats ? null : (routeStats ?? this.routeStats),
      isSnapping: isSnapping ?? this.isSnapping,
      isLoading: isLoading ?? this.isLoading,
      focusCoordinate: clearFocus ? null : (focusCoordinate ?? this.focusCoordinate),
      elevationMarkerCoord: clearElevationMarker
          ? null
          : (elevationMarkerCoord ?? this.elevationMarkerCoord),
      activeRouteId: clearActiveRoute ? null : (activeRouteId ?? this.activeRouteId),
      routeColor: routeColor ?? this.routeColor,
      editingRouteName: editingRouteName ?? this.editingRouteName,
    );
  }
}
