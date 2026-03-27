# routeapp/flutter — CLAUDE.md

> Global rules: `/c/web/CLAUDE.md`. Shared domain/API/feature rules: `/c/web/routeapp/CLAUDE.md`. This file covers Flutter-specific conventions only.

## Stack
Flutter (latest stable), Dart, `maplibre_gl`, Riverpod 2, `sqflite`, `supabase_flutter` v2, `geolocator`, `file_picker`, `share_plus`, `fl_chart`, `xml`

## Key Commands
```bash
flutter doctor          # verify dependencies
flutter pub get         # install packages
flutter run             # hot reload dev on connected device
flutter build apk --release --split-per-abi  # release APK
flutter build appbundle # AAB for Play Store
flutter clean           # fix most weird build errors
```

## Folder Structure
```
lib/
  main.dart
  features/
    map/          # MaplibreMap widget, waypoint markers, route polyline
    routing/      # Valhalla API client, routing provider
    routes/       # SQLite CRUD, route list screen
    gpx/          # GPX parser + exporter
    elevation/    # Elevation chart widget
    auth/         # Supabase auth
    sync/         # Cloud sync service
  models/
    waypoint.dart
    route_model.dart
    route_stats.dart
  services/
    db.dart           # sqflite wrapper
    supabase.dart     # Supabase client init
  state/
    route_provider.dart   # Riverpod StateNotifier for RouteState
    auth_provider.dart
    settings_provider.dart
android/
  app/src/main/AndroidManifest.xml   # permissions
```

## Conventions
- File names: `snake_case.dart`
- Class names: `PascalCase`
- Providers: `final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>(...)`
- No `BuildContext` passed into services — use ref in providers
- All SQLite queries use positional `?` params, never string interpolation
- `updated_at` set by app on every write (no DB trigger)
- All reads filter `WHERE deleted_at IS NULL`

## MapLibre Notes
- Style URL: `https://tiles.stadiamaps.com/styles/outdoors.json?api_key=$key`
- Long-press via `onLongPress: (LatLng pos) {}` on `MaplibreMap`
- Controller from `onMapCreated(MaplibreMapController controller)`
- See `docs/framework-notes/flutter.md` for package details and patterns

## Android Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

## Environment
```
# android/local.properties or passed via --dart-define
STADIA_API_KEY=...
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

Pass at build time: `flutter run --dart-define=STADIA_API_KEY=xxx`
Read in Dart: `const String.fromEnvironment('STADIA_API_KEY')`

## Documentation Maintenance

| Change | Update |
|---|---|
| New package added | `docs/framework-notes/flutter.md` (Packages table) |
| MapLibre usage pattern discovered | `docs/framework-notes/flutter.md` |
| SQLite schema change | `docs/architecture.md` + `lib/services/db.dart` migrations |
| GPX import/export change | `docs/api-contract.md` |
| Sync or auth flow change | `docs/architecture.md` |
| New Android permission | `android/app/src/main/AndroidManifest.xml` + `docs/setup-android.md` |
| Gotcha or build issue found | `docs/framework-notes/flutter.md` (Gotchas section) |

## Testing

```bash
flutter test              # run all tests
flutter test --coverage   # with coverage
```

- **Unit tests** — test Riverpod notifiers and pure functions (polyline6 decoder, GPX
  parser) without a running device.
- **Widget tests** — use `WidgetTester` to verify UI behaviour without a device.
- **Integration tests** — use `flutter drive` or `integration_test` package for
  on-device tests.
- Test files live alongside the file under test: `route_notifier_test.dart` next to
  `route_notifier.dart`.

## Docs
- `docs/framework-notes/flutter.md` — setup, packages, patterns, gotchas
- `docs/architecture.md` — shared domain model, state shape, sync strategy
- `docs/api-contract.md` — Valhalla API, GPX format, Supabase schema
- `docs/testing.md` — cross-framework testing philosophy
