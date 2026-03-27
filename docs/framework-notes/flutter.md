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

## Phase 2 Patterns

**Map layer switching:**
Call `controller.setStyleString(newUrl)` to switch layers. Custom images registered
via `addImage()` are cleared on style change. Pass a versioned `key` to overlay
widgets (`WaypointMarkersOverlay`, `RoutePolylineOverlay`) so they rebuild and
re-register images after `onStyleLoadedCallback` fires.

**Nominatim geocoding:**
Use `https://nominatim.openstreetmap.org/search?format=json&q=...&addressdetails=1`.
Must send a `User-Agent` header. Split `display_name` on `, ` for name vs location.

**Supabase initialization:**
Call `await Supabase.initialize(url, anonKey)` before `runApp()`. Guard with
`if (url.isNotEmpty)` so the app works without Supabase creds during development.
Auth stream: `Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session?.user)`.

**Settings provider async init:**
`SettingsNotifier` is an `AsyncNotifier` that loads SQLite values in `build()`.
Use `ref.watch(settingsProvider).value?.isImperial ?? false` in widgets to read
the setting with a safe fallback while loading.

## Phase 3 Patterns

**MapLibre offline API — top-level functions:**
`downloadOfflineRegion`, `getListOfRegions`, `deleteOfflineRegion` are imported
directly from `maplibre_gl` — they are NOT methods on the map controller.
`OfflineRegionDefinition` takes `double` zoom levels; metadata is a plain
`Map<String, dynamic>` (stored by MapLibre, retrieved via `OfflineRegion.metadata`).

**Bbox screen-space → LatLng conversion:**
The bbox selection rectangle is tracked as four screen-space `Offset` values
(left, top, right, bottom), not `LatLng`. Corners are converted only when needed
(drag-end for size estimate, save for download) via:
```dart
final sw = await controller.toLatLng(Point<double>(_left, _bottom));
final ne = await controller.toLatLng(Point<double>(_right, _top));
```
This avoids fighting map projection during drag and keeps corner movement 1:1 with the finger.

**Draggable corner dots (long-press gesture):**
Each corner is a `GestureDetector` using `onLongPressStart` / `onLongPressMoveUpdate` /
`onLongPressEnd`. Long-press (not tap-drag) prevents accidental corner moves when
panning the map. Map scroll/zoom gestures are disabled while `_draggingCorner != null`.

**DraggableScrollableController for regions sheet:**
The Downloaded Regions sheet uses `DraggableScrollableController` to programmatically
collapse to peek height when "View" is tapped, so the user sees the map zoom to the
region bounds:
```dart
await _sheetController.animateTo(peekFraction, duration: 250ms, curve: easeOut);
widget.onZoomToBounds(region.bounds);
```

**Size estimation (~15 KB/tile):**
Tile count is summed across zoom levels 5–14 using `ceil(span / 360 * 2^z)` per axis.
Multiplied by 15 KB gives a rough MB estimate displayed in real-time on the bbox screen.

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
