import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Displays an elevation profile chart.
///
/// [elevationData] is a list of [distanceKm, elevationM] pairs.
/// [markerIndex] is the index of the currently highlighted point (null = none).
/// [onTapIndex] is called with the data-point index when the user taps the chart.
///   The caller can cross-reference this index against the route geometry
///   coordinates, since the elevation API returns one point per input coordinate.
/// [onDragIndex] is called while scrubbing without flying the camera.
class ElevationProfile extends StatelessWidget {
  final List<List<double>> elevationData;
  final int? markerIndex;

  /// Called on tap — fly camera to this index in the route coords.
  final void Function(int index)? onTapIndex;

  /// Called on drag — show marker without flying camera.
  final void Function(int index)? onDragIndex;

  const ElevationProfile({
    super.key,
    required this.elevationData,
    this.markerIndex,
    this.onTapIndex,
    this.onDragIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (elevationData.isEmpty) return const SizedBox.shrink();

    final spots = elevationData
        .asMap()
        .entries
        .map((e) => FlSpot(e.value[0], e.value[1]))
        .toList();

    final minElev =
        elevationData.map((e) => e[1]).reduce((a, b) => a < b ? a : b);
    final maxElev =
        elevationData.map((e) => e[1]).reduce((a, b) => a > b ? a : b);
    final elevRange = (maxElev - minElev).clamp(10.0, double.infinity);
    final elevPadding = elevRange * 0.12;

    final totalDist = elevationData.last[0];
    final midDist = totalDist / 2;

    // Stats row values
    final stats = _buildStats(context);

    return Container(
      color: Colors.white.withOpacity(0.97),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats row
          stats,
          const SizedBox(height: 4),
          // Chart
          SizedBox(
            height: 110,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return Text(
                            '${value.toInt()}m',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: totalDist > 0 ? totalDist : 1,
                      getTitlesWidget: (value, meta) {
                        final isStart = (value - spots.first.x).abs() < 0.001;
                        final isMid = (value - midDist).abs() < totalDist * 0.1;
                        final isEnd = (value - spots.last.x).abs() < 0.001;
                        if (!isStart && !isMid && !isEnd) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.toStringAsFixed(1)}km',
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minElev - elevPadding,
                maxY: maxElev + elevPadding,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (_) => [],
                  ),
                  touchCallback: (event, response) {
                    if (response?.lineBarSpots == null) return;
                    final idx = response!.lineBarSpots!.first.spotIndex;
                    if (event is FlTapUpEvent) {
                      onTapIndex?.call(idx);
                    } else if (event is FlPanUpdateEvent ||
                        event is FlLongPressMoveUpdate) {
                      onDragIndex?.call(idx);
                    }
                  },
                ),
                extraLinesData: markerIndex != null &&
                        markerIndex! < elevationData.length
                    ? ExtraLinesData(verticalLines: [
                        VerticalLine(
                          x: elevationData[markerIndex!][0],
                          color: Colors.black54,
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                      ])
                    : null,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF3b82f6),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: markerIndex != null,
                      checkToShowDot: (spot, _) =>
                          markerIndex != null && spot.spotIndex == markerIndex,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF3b82f6),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3b82f6).withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    if (elevationData.isEmpty) return const SizedBox.shrink();

    double gain = 0, loss = 0;
    for (int i = 1; i < elevationData.length; i++) {
      final diff = elevationData[i][1] - elevationData[i - 1][1];
      if (diff > 0) {
        gain += diff;
      } else {
        loss -= diff;
      }
    }
    final distKm = elevationData.last[0];
    final dist = distKm >= 1
        ? '${distKm.toStringAsFixed(2)} km'
        : '${(distKm * 1000).toStringAsFixed(0)} m';

    // If there's a marker, show elevation at that point
    Widget? scrubInfo;
    if (markerIndex != null && markerIndex! < elevationData.length) {
      final pt = elevationData[markerIndex!];
      scrubInfo = Text(
        '${pt[1].toStringAsFixed(0)}m at ${pt[0].toStringAsFixed(2)}km',
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      );
    }

    return Row(
      children: [
        Text(
          dist,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Text(
          '↑ ${gain.toStringAsFixed(0)}m',
          style: const TextStyle(fontSize: 11, color: Colors.green),
        ),
        const SizedBox(width: 8),
        Text(
          '↓ ${loss.toStringAsFixed(0)}m',
          style: const TextStyle(fontSize: 11, color: Colors.red),
        ),
        if (scrubInfo != null) ...[
          const Spacer(),
          scrubInfo,
        ],
      ],
    );
  }
}
