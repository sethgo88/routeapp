import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/saved_route.dart';
import '../../services/db.dart' as db;
import '../../state/route_notifier.dart';

final savedRoutesProvider = FutureProvider<List<SavedRoute>>((ref) => db.listRoutes());

class RouteListModal extends ConsumerWidget {
  const RouteListModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(savedRoutesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'My Routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: routesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error loading routes: $e')),
                data: (routes) {
                  if (routes.isEmpty) {
                    return const Center(
                      child: Text('No saved routes yet.\nLong-press the map to start.'),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: routes.length,
                    itemBuilder: (context, i) {
                      final route = routes[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(route.color.replaceFirst('#', '0xFF')),
                          ),
                        ),
                        title: Text(route.name),
                        subtitle: route.stats != null
                            ? Text(
                                '${route.stats!.distanceKm.toStringAsFixed(2)} km')
                            : null,
                        onTap: () async {
                          await ref
                              .read(routeProvider.notifier)
                              .loadRouteForEditing(route.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await db.deleteRoute(route.id);
                            ref.invalidate(savedRoutesProvider);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
