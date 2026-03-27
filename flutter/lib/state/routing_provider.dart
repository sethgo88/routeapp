import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/routing.dart';
import 'route_notifier.dart';

class RoutingNotifier extends Notifier<AsyncValue<RouteResult?>> {
  @override
  AsyncValue<RouteResult?> build() => const AsyncValue.data(null);

  Future<void> triggerRouting() async {
    final routeState = ref.read(routeProvider);
    final waypoints = routeState.waypoints;

    if (waypoints.length < 2) {
      ref.read(routeProvider.notifier).setRoute(null);
      ref.read(routeProvider.notifier).setElevationData([]);
      ref.read(routeProvider.notifier).setRouteStats(null);
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    ref.read(routeProvider.notifier).setIsLoading(true);

    try {
      final result = await fetchRouteSegmented(waypoints);
      ref.read(routeProvider.notifier).setRoute(result.geometry);
      ref.read(routeProvider.notifier).setElevationData(result.elevationData);
      ref.read(routeProvider.notifier).setRouteStats(result.stats);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      ref.read(routeProvider.notifier).setIsLoading(false);
    }
  }
}

final routingProvider =
    NotifierProvider<RoutingNotifier, AsyncValue<RouteResult?>>(
        RoutingNotifier.new);
