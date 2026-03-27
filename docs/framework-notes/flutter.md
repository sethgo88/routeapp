# Flutter Notes

Framework-specific lessons, patterns, and gotchas for the Flutter implementation.

## Setup (Windows 11)

1. Download Flutter SDK from https://flutter.dev → extract to `C:\flutter` (no spaces in path)
2. Add `C:\flutter\bin` to PATH
3. Run `flutter doctor` — follow all prompts to resolve issues
4. Accept Android licenses: `flutter doctor --android-licenses`

Common `flutter doctor` issues on Windows:
- "Android toolchain - No cmdline-tools" → Android Studio SDK Manager → install "Android SDK Command-line Tools"
- "Visual Studio not installed" → can ignore if only targeting Android

## Key Commands

```bash
flutter doctor             # verify all dependencies
flutter pub get            # install packages
flutter run                # hot reload dev build on connected device
flutter run --release      # release build to device
flutter build apk --release            # release APK for sideloading
flutter build apk --split-per-abi      # smaller per-ABI APKs
flutter build appbundle                # AAB for Play Store
flutter clean                          # clear build cache (fixes most weird errors)
```

## MapLibre (`maplibre_gl`)

- Package: `maplibre_gl` on pub.dev (formerly `flutter_mapbox_gl`)
- Add to `android/app/build.gradle`: minSdkVersion 21
- The controller is obtained via `MaplibreMapController` from `onMapCreated` callback
- Map style URL: Stadia outdoors = `https://tiles.stadiamaps.com/styles/outdoors.json?api_key=KEY`

**Long-press to add waypoint:**
```dart
MaplibreMap(
  onLongPress: (LatLng pos) => addWaypoint(pos),
  ...
)
```

**Adding a symbol (waypoint marker):**
```dart
await controller.addSymbol(SymbolOptions(
  geometry: LatLng(lat, lon),
  iconImage: 'marker',
  textField: 'A',
));
```

**Drawing a route polyline:**
```dart
await controller.addLine(LineOptions(
  geometry: coords, // List<LatLng>
  lineColor: '#3b82f6',
  lineWidth: 3.0,
));
```

## State Management (Riverpod)

- Use `StateNotifierProvider` or `NotifierProvider` (Riverpod 2.x) for route state
- Equivalent to Zustand: `ref.read(routeProvider.notifier).addWaypoint(...)`
- Equivalent to TanStack Query: `ref.watch(routingQueryProvider)` with `AsyncValue`

## Gotchas

_Fill in as discovered during implementation._

## Packages

| Purpose | Package |
|---|---|
| Maps | `maplibre_gl` |
| GPS | `geolocator` |
| File picker | `file_picker` |
| File sharing | `share_plus` |
| SQLite | `sqflite` + `path_provider` |
| Supabase | `supabase_flutter` |
| State | `flutter_riverpod` |
| HTTP | `http` or `dio` |
| Charts | `fl_chart` |
| XML parsing | `xml` package |
