import 'map.dart' show stadiaApiKey;

enum MapLayer { satellite, topo, trail, street }

extension MapLayerExtension on MapLayer {
  String get label => switch (this) {
        MapLayer.satellite => 'Satellite',
        MapLayer.topo => 'Topo',
        MapLayer.trail => 'Trail overlay',
        MapLayer.street => 'Street/Road',
      };

  String get styleUrl => switch (this) {
        MapLayer.satellite =>
          'https://tiles.stadiamaps.com/styles/alidade_satellite.json?api_key=$stadiaApiKey',
        MapLayer.topo =>
          'https://tiles.stadiamaps.com/styles/stamen_terrain.json?api_key=$stadiaApiKey',
        MapLayer.trail =>
          'https://tiles.stadiamaps.com/styles/outdoors.json?api_key=$stadiaApiKey',
        MapLayer.street =>
          'https://tiles.stadiamaps.com/styles/alidade_smooth.json?api_key=$stadiaApiKey',
      };

  String get settingsValue => name;
}

MapLayer mapLayerFromSettingsValue(String value) =>
    MapLayer.values.firstWhere((l) => l.name == value,
        orElse: () => MapLayer.trail);
