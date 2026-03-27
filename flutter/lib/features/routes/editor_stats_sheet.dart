import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/route_notifier.dart';
import '../../state/route_state.dart';
import '../../state/settings_provider.dart';
import '../../utils/format.dart';
import '../elevation/elevation_profile.dart';

// Color swatches: white, black, gray, then light+dark pairs of
// red, orange, yellow, green, blue, indigo, violet
const _swatchColors = [
  Color(0xFFFFFFFF), // white
  Color(0xFF111111), // black
  Color(0xFF6B7280), // gray
  Color(0xFFFCA5A5), // red-300
  Color(0xFFEF4444), // red-500
  Color(0xFFFDBA74), // orange-300
  Color(0xFFF97316), // orange-500
  Color(0xFFFDE047), // yellow-300
  Color(0xFFEAB308), // yellow-500
  Color(0xFF86EFAC), // green-300
  Color(0xFF22C55E), // green-500
  Color(0xFF93C5FD), // blue-300
  Color(0xFF3B82F6), // blue-500
  Color(0xFFA5B4FC), // indigo-300
  Color(0xFF6366F1), // indigo-500
  Color(0xFFD8B4FE), // violet-300
  Color(0xFF8B5CF6), // violet-500
];

String _colorToHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}'
    '${c.green.toRadixString(16).padLeft(2, '0')}'
    '${c.blue.toRadixString(16).padLeft(2, '0')}';

class EditorStatsSheet extends ConsumerStatefulWidget {
  /// Called when user taps the elevation chart — fly camera to index in route coords.
  final void Function(int index)? onElevationTap;

  /// Called when back button is pressed (checks unsaved changes upstream).
  final VoidCallback onBack;

  /// Called after save is complete so the editor can pop.
  final VoidCallback onSaved;

  /// Called after delete is confirmed so the editor can pop.
  final VoidCallback onDeleted;

  const EditorStatsSheet({
    super.key,
    this.onElevationTap,
    required this.onBack,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  ConsumerState<EditorStatsSheet> createState() => _EditorStatsSheetState();
}

class _EditorStatsSheetState extends ConsumerState<EditorStatsSheet> {
  late TextEditingController _nameCtrl;
  final TextEditingController _paceCtrl = TextEditingController();
  int? _markerIndex;
  bool _saving = false;

  // Fractions for snap positions
  static const double _snapClosed = 0.07;
  static const double _snapMid = 0.38;
  static const double _snapFull = 0.66;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(routeProvider).editingRouteName,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _paceCtrl.dispose();
    super.dispose();
  }

  String _estimatedTime(double distanceKm, {bool imperial = false}) {
    final pace = double.tryParse(_paceCtrl.text);
    if (pace == null || pace <= 0) return '—';
    final mins = estimatedMinutes(distanceKm, pace, imperial: imperial);
    return formatDuration(mins);
  }

  Future<void> _save() async {
    if (_saving) return;
    final state = ref.read(routeProvider);
    if (state.route == null || state.waypoints.isEmpty) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a route name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(routeProvider.notifier)
          .saveCurrentRoute(name: name, stats: state.routeStats);
      if (mounted) widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete route'),
        content: const Text(
          'Are you sure you want to delete this route?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(routeProvider.notifier).deleteCurrentRoute();
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeProvider);

    // Keep name field in sync when state is reset
    if (_nameCtrl.text != state.editingRouteName &&
        state.editingRouteName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameCtrl.text = state.editingRouteName;
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: _snapClosed,
      minChildSize: _snapClosed,
      maxChildSize: _snapFull,
      snap: true,
      snapSizes: const [_snapClosed, _snapMid, _snapFull],
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
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHandle()),
              SliverToBoxAdapter(child: _buildHeaderRow(state)),
              if (state.elevationData.isNotEmpty)
                SliverToBoxAdapter(
                  child: ElevationProfile(
                    elevationData: state.elevationData,
                    markerIndex: _markerIndex,
                    onTapIndex: (idx) {
                      setState(() => _markerIndex = idx);
                      widget.onElevationTap?.call(idx);
                    },
                    onDragIndex: (idx) => setState(() => _markerIndex = idx),
                  ),
                ),
              SliverToBoxAdapter(child: _buildColorSwatches(state)),
              SliverToBoxAdapter(child: _buildPaceRow(state)),
              SliverToBoxAdapter(child: _buildActionRow(state)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(RouteState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: widget.onBack,
            tooltip: 'Back',
          ),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Route name',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (v) =>
                  ref.read(routeProvider.notifier).setEditingRouteName(v),
            ),
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: state.route != null ? _save : null,
            tooltip: 'Save',
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatches(RouteState state) {
    final currentHex = state.routeColor.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _swatchColors.map((color) {
          final hex = _colorToHex(color);
          final isSelected = hex == currentHex ||
              hex == currentHex.replaceFirst('#', '');
          return GestureDetector(
            onTap: () =>
                ref.read(routeProvider.notifier).setRouteColor(hex),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.black
                      : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaceRow(RouteState state) {
    final distKm = state.routeStats?.distanceKm ?? 0.0;
    final imperial =
        ref.watch(settingsProvider).value?.isImperial ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: TextField(
              controller: _paceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: paceLabel(imperial: imperial),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Est. time: ${_estimatedTime(distKm, imperial: imperial)}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(RouteState state) {
    final canDelete = state.editingMode == EditingMode.editing &&
        state.activeRouteId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: state.route != null ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: canDelete ? _confirmDelete : null,
              style: FilledButton.styleFrom(
                backgroundColor: canDelete ? Colors.red : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Delete', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
