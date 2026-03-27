import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/map_layers.dart';
import '../services/db.dart' as db;

class SettingsState {
  final String unitSystem; // 'metric' | 'imperial'
  final MapLayer defaultLayer;

  const SettingsState({
    this.unitSystem = 'metric',
    this.defaultLayer = MapLayer.trail,
  });

  bool get isImperial => unitSystem == 'imperial';

  SettingsState copyWith({String? unitSystem, MapLayer? defaultLayer}) =>
      SettingsState(
        unitSystem: unitSystem ?? this.unitSystem,
        defaultLayer: defaultLayer ?? this.defaultLayer,
      );
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final unitSystem = await db.getSetting('unit_system') ?? 'metric';
    final layerValue = await db.getSetting('default_layer') ?? 'trail';
    return SettingsState(
      unitSystem: unitSystem,
      defaultLayer: mapLayerFromSettingsValue(layerValue),
    );
  }

  Future<void> setUnitSystem(String value) async {
    await db.setSetting('unit_system', value);
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(unitSystem: value));
  }

  Future<void> setDefaultLayer(MapLayer layer) async {
    await db.setSetting('default_layer', layer.settingsValue);
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(defaultLayer: layer));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Convenience: current active map layer for this session.
/// Starts null → falls back to settings default → falls back to trail.
final activeLayerProvider = StateProvider<MapLayer?>((ref) => null);
