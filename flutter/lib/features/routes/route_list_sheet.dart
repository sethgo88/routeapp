import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/saved_route.dart';
import '../../state/settings_provider.dart';
import '../../utils/format.dart';
import '../gpx/gpx_parser.dart';
import '../routes/route_list_modal.dart' show savedRoutesProvider;
import '../routes/route_editor_screen.dart';

class RouteListSheet extends ConsumerWidget {
  final void Function(int routeId) onRouteSelected;
  final VoidCallback onNewRoute;
  /// Called after the editor opened via GPX import closes.
  final VoidCallback? onAfterImport;

  const RouteListSheet({
    super.key,
    required this.onRouteSelected,
    required this.onNewRoute,
    this.onAfterImport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(savedRoutesProvider);
    final mediaQuery = MediaQuery.of(context);
    // Peek shows handle + ~28px of content
    final peekFraction = (72 + mediaQuery.padding.bottom) / mediaQuery.size.height;

    return DraggableScrollableSheet(
      initialChildSize: peekFraction.clamp(0.08, 0.15),
      minChildSize: peekFraction.clamp(0.08, 0.15),
      maxChildSize: 0.92,
      snap: true,
      snapSizes: [peekFraction.clamp(0.08, 0.15), 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable route list
              Expanded(
                child: routesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error: $e')),
                  data: (routes) {
                    if (routes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No routes yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: onNewRoute,
                                icon: const Icon(Icons.add),
                                label: const Text('Add a route'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final settings =
                        ref.watch(settingsProvider).value;
                    final imperial = settings?.isImperial ?? false;
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: routes.length,
                      itemBuilder: (context, i) => _RouteRow(
                        route: routes[i],
                        onTap: onRouteSelected,
                        imperial: imperial,
                      ),
                    );
                  },
                ),
              ),

              // Import button — fixed at bottom
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import GPX'),
                      onPressed: () => _importGpx(context, ref),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importGpx(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final contents =
        await File(result.files.single.path!).readAsString();
    final waypoints = parseGpx(contents);
    if (!context.mounted) return;
    if (waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No track points found in GPX file')),
      );
      return;
    }
    // Open editor with imported waypoints
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteEditorScreen(importedWaypoints: waypoints),
      ),
    );
    ref.invalidate(savedRoutesProvider);
    onAfterImport?.call();
  }
}

class _RouteRow extends StatelessWidget {
  final SavedRoute route;
  final void Function(int) onTap;
  final bool imperial;

  const _RouteRow({
    required this.route,
    required this.onTap,
    required this.imperial,
  });

  String _formatStat() {
    if (route.stats == null) return '';
    final dist = formatDistance(route.stats!.distanceKm, imperial: imperial);
    final gain = '↑ ${formatElevation(route.stats!.gainM, imperial: imperial)}';
    final loss = '↓ ${formatElevation(route.stats!.lossM, imperial: imperial)}';
    return '$dist · $gain · $loss';
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.tryParse(route.color.replaceFirst('#', '0xFF')) ?? 0xFF3b82f6,
    );
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        route.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatStat(),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () => onTap(route.id),
      dense: true,
    );
  }
}
