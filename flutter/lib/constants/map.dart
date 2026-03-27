const String stadiaApiKey = String.fromEnvironment('STADIA_API_KEY');

const String valhallaBaseUrl = 'https://valhalla1.openstreetmap.de';

String get mapStyleUrl =>
    'https://tiles.stadiamaps.com/styles/outdoors.json?api_key=$stadiaApiKey';

const String defaultRouteColor = '#3b82f6';

// Label sequence for waypoints: A, B, C, ...
String waypointLabel(int index) {
  if (index < 26) return String.fromCharCode(65 + index); // A-Z
  return '${index + 1}'; // fallback to numbers beyond Z
}
