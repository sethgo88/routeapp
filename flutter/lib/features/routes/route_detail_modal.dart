import 'package:flutter/material.dart';
import '../../models/saved_route.dart';

class RouteDetailModal extends StatefulWidget {
  final SavedRoute route;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const RouteDetailModal({
    super.key,
    required this.route,
    required this.onClose,
    required this.onEdit,
    required this.onExport,
  });

  @override
  State<RouteDetailModal> createState() => _RouteDetailModalState();
}

class _RouteDetailModalState extends State<RouteDetailModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _statsLine() {
    final s = widget.route.stats;
    if (s == null) return '';
    final d = s.distanceKm;
    final dist = d >= 1
        ? '${d.toStringAsFixed(1)} km'
        : '${(d * 1000).toStringAsFixed(0)} m';
    return '$dist · ↑ ${s.gainM.toStringAsFixed(0)} m · ↓ ${s.lossM.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Stack(
        children: [
          // Transparent tap-away backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Floating card — centered
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.route.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: widget.onClose,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),

                      // Stats line
                      if (widget.route.stats != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _statsLine(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: widget.onExport,
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Export'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
