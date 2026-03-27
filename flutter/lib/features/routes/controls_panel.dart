import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../../state/route_notifier.dart';
import '../../state/route_state.dart';
import '../../state/routing_provider.dart';
import '../../features/gpx/gpx_parser.dart';
import '../../features/gpx/gpx_exporter.dart';
import '../../services/db.dart' as db;
import 'route_list_modal.dart';
import 'name_route_modal.dart';

class ControlsPanel extends ConsumerWidget {
  final VoidCallback onLocationCenter;
  final VoidCallback onScheduleRouting;

  const ControlsPanel({
    super.key,
    required this.onLocationCenter,
    required this.onScheduleRouting,
  });

  Future<void> _importGpx(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final contents = await File(result.files.single.path!).readAsString();
    final waypoints = parseGpx(contents);
    if (waypoints.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No track points found in GPX file')),
        );
      }
      return;
    }
    ref.read(routeProvider.notifier).loadWaypoints(waypoints);
    ref.read(routeProvider.notifier).setEditingMode(EditingMode.creating);
    onScheduleRouting();
  }

  Future<void> _exportGpx(BuildContext context, WidgetRef ref) async {
    final state = ref.read(routeProvider);
    if (state.route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No route to export')),
      );
      return;
    }
    final gpx = exportGpx(
      geometry: state.route!,
      elevationData: state.elevationData,
      name: state.editingRouteName.isNotEmpty ? state.editingRouteName : 'Route',
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/route.gpx');
    await file.writeAsString(gpx);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Route GPX'),
    );
  }

  Future<void> _saveRoute(BuildContext context, WidgetRef ref) async {
    final state = ref.read(routeProvider);
    if (state.route == null || state.waypoints.isEmpty) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameRouteModal(
        initialName: state.editingRouteName,
      ),
    );
    if (name == null || name.isEmpty) return;

    if (state.editingMode == EditingMode.editing && state.activeRouteId != null) {
      await db.updateRoute(
        id: state.activeRouteId!,
        name: name,
        color: state.routeColor,
        waypoints: state.waypoints,
        geometry: state.route!,
        stats: state.routeStats,
      );
    } else {
      await db.saveRoute(
        name: name,
        color: state.routeColor,
        waypoints: state.waypoints,
        geometry: state.route!,
        stats: state.routeStats,
      );
    }

    ref.read(routeProvider.notifier).clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$name"')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeProvider);
    final hasWaypoints = state.waypoints.isNotEmpty;
    final hasRoute = state.route != null;
    final isEditing = state.editingMode != EditingMode.view;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stats row
            if (state.routeStats != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(
                      label: 'Distance',
                      value: '${state.routeStats!.distanceKm.toStringAsFixed(2)} km',
                    ),
                    _StatChip(
                      label: 'Gain',
                      value: '+${state.routeStats!.gainM.toStringAsFixed(0)}m',
                    ),
                    _StatChip(
                      label: 'Loss',
                      value: '-${state.routeStats!.lossM.toStringAsFixed(0)}m',
                    ),
                  ],
                ),
              ),

            // Snap toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Snap to trails'),
                Switch(
                  value: state.isSnapping,
                  onChanged: (v) =>
                      ref.read(routeProvider.notifier).setIsSnapping(v),
                ),
              ],
            ),

            // Action buttons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'My Routes',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => const RouteListModal(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'Import GPX',
                  onPressed: () => _importGpx(context, ref),
                ),
                if (hasRoute) ...[
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: 'Export GPX',
                    onPressed: () => _exportGpx(context, ref),
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Save Route',
                    onPressed: () => _saveRoute(context, ref),
                  ),
                ],
                if (hasWaypoints) ...[
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Undo',
                    onPressed: ref.read(routeProvider.notifier).canUndo
                        ? () {
                            ref.read(routeProvider.notifier).undo();
                            onScheduleRouting();
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    tooltip: 'Redo',
                    onPressed: ref.read(routeProvider.notifier).canRedo
                        ? () {
                            ref.read(routeProvider.notifier).redo();
                            onScheduleRouting();
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear All',
                    onPressed: () =>
                        ref.read(routeProvider.notifier).clearAll(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
