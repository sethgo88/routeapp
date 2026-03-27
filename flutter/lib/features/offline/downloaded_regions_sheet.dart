import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../models/offline_region.dart';
import 'bbox_selection_screen.dart';

/// Bottom sheet overlaid on the home map listing saved offline tile regions.
/// Snap positions: peek (handle only) and 40% screen height.
class DownloadedRegionsSheet extends StatefulWidget {
  /// Called when the in-sheet back button is pressed (returns to Settings).
  final VoidCallback onBackToSettings;

  /// Called to zoom the map to the given bbox when "View" is tapped.
  final void Function(LatLngBounds bounds) onZoomToBounds;

  const DownloadedRegionsSheet({
    super.key,
    required this.onBackToSettings,
    required this.onZoomToBounds,
  });

  @override
  State<DownloadedRegionsSheet> createState() =>
      _DownloadedRegionsSheetState();
}

class _DownloadedRegionsSheetState
    extends State<DownloadedRegionsSheet> {
  List<OfflineRegionInfo>? _regions;
  bool _loading = true;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    setState(() => _loading = true);
    try {
      final raw = await getListOfRegions();
      if (mounted) {
        setState(() {
          _regions = raw
              .map(OfflineRegionInfo.fromOfflineRegion)
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRegion(OfflineRegionInfo region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete region?'),
        content: Text(
          'Are you sure you want to delete "${region.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteOfflineRegion(region.id);
    await _loadRegions();
  }

  Future<void> _viewRegion(OfflineRegionInfo region) async {
    // Collapse sheet to peek so user can see the map.
    if (_sheetController.isAttached) {
      final mediaQuery = MediaQuery.of(context);
      final peekFraction =
          (72 + mediaQuery.padding.bottom) / mediaQuery.size.height;
      await _sheetController.animateTo(
        peekFraction.clamp(0.08, 0.15),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    widget.onZoomToBounds(region.bounds);
  }

  Future<void> _openBboxSelection() async {
    final downloaded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BboxSelectionScreen()),
    );
    if (downloaded == true) await _loadRegions();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final peekFraction =
        (72 + mediaQuery.padding.bottom) / mediaQuery.size.height;
    const openFraction = 0.40;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: openFraction,
      minChildSize: peekFraction.clamp(0.08, 0.15),
      maxChildSize: openFraction,
      snap: true,
      snapSizes: [peekFraction.clamp(0.08, 0.15), openFraction],
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Padding(
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
              ),

              // Back button row
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBackToSettings,
                      icon: const Icon(Icons.chevron_left, size: 20),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Downloaded Regions',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const Spacer(),
                    const SizedBox(width: 56), // balance back button
                  ],
                ),
              ),

              // "+ Download region" button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Download region'),
                  onPressed: _openBboxSelection,
                ),
              ),

              const Divider(height: 1),

              // Region list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_regions == null || _regions!.isEmpty)
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No downloaded regions',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _regions!.length,
                            itemBuilder: (ctx, i) => _RegionRow(
                              region: _regions![i],
                              onView: () => _viewRegion(_regions![i]),
                              onDelete: () =>
                                  _deleteRegion(_regions![i]),
                            ),
                          ),
              ),

              // Bottom safe area padding
              SizedBox(height: mediaQuery.padding.bottom),
            ],
          ),
        );
      },
    );
  }
}

class _RegionRow extends StatelessWidget {
  final OfflineRegionInfo region;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _RegionRow({
    required this.region,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  region.formattedSize,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onView,
            child: const Text('View'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
