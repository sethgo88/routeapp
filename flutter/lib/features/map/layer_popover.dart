import 'package:flutter/material.dart';
import '../../constants/map_layers.dart';

/// Popover listing map layer options.
/// Positioned by the parent (Stack + Positioned) to appear left of the
/// layers icon, top-aligned with it.
class LayerPopover extends StatelessWidget {
  final MapLayer activeLayer;
  final void Function(MapLayer) onLayerSelected;

  const LayerPopover({
    super.key,
    required this.activeLayer,
    required this.onLayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(10),
      elevation: 6,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: MapLayer.values
                .map((layer) => _LayerRow(
                      layer: layer,
                      isActive: layer == activeLayer,
                      onTap: () => onLayerSelected(layer),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final MapLayer layer;
  final bool isActive;
  final VoidCallback onTap;

  const _LayerRow({
    required this.layer,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isActive ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.grey.shade200
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          layer.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
