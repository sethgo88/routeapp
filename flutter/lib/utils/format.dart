/// Format a distance (in km) for display.
/// Below threshold: meters or feet. At/above: km or miles with 2 dp.
String formatDistance(double km, {bool imperial = false}) {
  if (imperial) {
    final miles = km * 0.621371;
    if (miles < 1.0) {
      return '${(km * 3280.84).round()} ft';
    }
    return '${miles.toStringAsFixed(2)} mi';
  }
  if (km < 1.0) {
    return '${(km * 1000).round()} m';
  }
  return '${km.toStringAsFixed(2)} km';
}

/// Format elevation (in metres) for display.
/// Always in meters or feet — never km/miles.
String formatElevation(double meters, {bool imperial = false}) {
  if (imperial) {
    return '${(meters * 3.28084).round()} ft';
  }
  return '${meters.round()} m';
}

/// Pace input label.
String paceLabel({bool imperial = false}) =>
    imperial ? 'Pace (min/mi)' : 'Pace (min/km)';

/// Estimated time in minutes given distance (km) and pace value
/// (min/km for metric, min/mi for imperial).
double estimatedMinutes(
  double distanceKm,
  double paceValue, {
  bool imperial = false,
}) {
  if (imperial) {
    return distanceKm * 0.621371 * paceValue;
  }
  return distanceKm * paceValue;
}

/// Format total minutes as "Xh Ym" or "Ym".
String formatDuration(double totalMinutes) {
  final rounded = totalMinutes.round();
  final h = rounded ~/ 60;
  final m = rounded % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}
