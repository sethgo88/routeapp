import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/route_notifier.dart';
import '../../state/route_state.dart';

class ElevationProfile extends ConsumerWidget {
  final List<List<double>> elevationData; // [[distanceKm, elevM], ...]
  final void Function(List<double> coord)? onTap;

  const ElevationProfile({
    super.key,
    required this.elevationData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (elevationData.isEmpty) return const SizedBox.shrink();

    final spots = elevationData
        .map((e) => FlSpot(e[0], e[1]))
        .toList();

    final minElev = elevationData.map((e) => e[1]).reduce((a, b) => a < b ? a : b);
    final maxElev = elevationData.map((e) => e[1]).reduce((a, b) => a > b ? a : b);
    final elevPadding = ((maxElev - minElev) * 0.1).clamp(5.0, double.infinity);

    return Container(
      height: 160,
      color: Colors.white.withOpacity(0.95),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) => Text(
                  '${value.toInt()}m',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) => Text(
                  '${value.toStringAsFixed(1)}km',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: minElev - elevPadding,
          maxY: maxElev + elevPadding,
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response?.lineBarSpots != null) {
                final spot = response!.lineBarSpots!.first;
                final idx = spot.spotIndex;
                // elevationData[idx] is [distanceKm, elevM]
                // We need [lon, lat] — not available here without the route coords
                // For now we pass the distanceKm index as a signal to the parent
                // TODO: cross-reference with route geometry for exact lon/lat
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF3b82f6),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF3b82f6).withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
