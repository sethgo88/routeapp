# routeapp/flutter — CLAUDE.md

> Global rules: `/c/web/CLAUDE.md`. Shared domain/API/feature rules: `/c/web/routeapp/CLAUDE.md`. This file is the **single start-here document** for the Flutter implementation. Read this before any source file.

---

## Phase Status

| Phase | Status | Summary |
|---|---|---|
| Phase 1 | ✅ Complete | Map, editor, waypoints, routing, elevation, GPX, SQLite |
| Phase 2 | ✅ Complete | Layer switcher, search, settings, auth, cloud sync, unit display |
| Phase 3 | 🔲 Pending | Offline map tile download (bbox selection, downloaded regions sheet) |

### Phase 1 — Completed Features
- Home map with all saved routes drawn simultaneously in their own colors
- Route List Sheet (always-peeking bottom sheet)
- Route Detail Modal (tap route → name, stats, Edit/Export buttons)
- Route Editor (full-screen map, long-press drops waypoints)
- Waypoint drag/select/delete, undo/redo stacks
- Snap-to-trail toggle (per-segment `snapAfter` flag, Valhalla routing)
- Elevation profile chart (`fl_chart`), tap-to-fly camera pan
- Color swatches (17 colors)
- GPX import (file picker → editor) and export (Android share intent)
- SQLite persistence with soft deletes (`deleted_at`)

### Phase 2 — Completed Features
- Map layer switcher popover (Satellite / Topo / Trail overlay / Street–Road)
  - Active layer persisted to SQLite `settings` table as `default_layer`
  - Style switch via `controller.setStyleString()`; overlays rebuild via `_styleVersion` key
- Search modal (Nominatim geocoding, fade-in, tap result pans map)
- Settings screen (units toggle km↔mi, default layer dropdown, account section)
- Supabase auth: email/password sign-in, register, forgot password, sign out
- Cloud sync: push (upsert local → Supabase), pull (insert remote-only locally), unit_system sync
- Unit-aware display everywhere: `formatDistance` / `formatElevation` from `lib/utils/format.dart`

### Phase 3 — What Needs to Be Built
See `docs/features.md` §9–10 for full spec. Key pieces:
- **Downloaded Regions Sheet** — bottom sheet on home map listing saved offline regions
- **Bbox Selection screen** — full-screen map with draggable corner rectangle, name input, download trigger
- **MapLibre offline tile download** — `controller.addOfflineTiles(region)` or equivalent
- **Delete region** — confirmation modal, remove from MapLibre offline store

---

## Stack

Flutter (latest stable), Dart, `maplibre_gl`, Riverpod 2, `sqflite`, `supabase_flutter` v2, `geolocator`, `file_picker`, `share_plus`, `fl_chart`, `xml`, `http`

---

## Folder Structure

```
lib/
  main.dart                      # ProviderScope, Supabase.initialize(), runApp()
  constants/
    map.dart                     # stadiaApiKey, valhallaBaseUrl, mapStyleUrl (outdoors), waypointLabel()
    map_layers.dart              # MapLayer enum (satellite/topo/trail/street) + styleUrl extension
  utils/
    format.dart                  # formatDistance(), formatElevation(), paceLabel(), estimatedMinutes()
  models/
    waypoint.dart                # Waypoint: id, lat, lon, label, snapAfter
    route_stats.dart             # RouteStats: distanceKm, gainM, lossM
    saved_route.dart             # SavedRoute: id, remoteId, name, color, waypoints, geometry, stats,
                                 #   createdAt, updatedAt, deletedAt
  services/
    db.dart                      # sqflite wrapper — listRoutes, listRoutesAll, getRoute,
                                 #   getRouteByRemoteId, saveRoute, updateRoute, deleteRoute,
                                 #   setRemoteId, insertFromRemote, getSetting, setSetting
    routing.dart                 # Valhalla client — polyline6 decode, segmented routing, elevation fetch
  state/
    route_state.dart             # RouteState immutable class + EditingMode enum
    route_notifier.dart          # RouteNotifier (NotifierProvider) — all waypoint/route mutations
    routing_provider.dart        # routingProvider — triggers Valhalla fetch, updates route + elevation
    settings_provider.dart       # SettingsNotifier (AsyncNotifier) — unitSystem + defaultLayer from SQLite
                                 # activeLayerProvider (StateProvider<MapLayer?>) — session layer
    auth_provider.dart           # authUserProvider (StreamProvider<User?>) + AuthNotifier
  features/
    map/
      map_screen.dart            # Home map: all routes, layer popover, search, settings nav, GPS
      layer_popover.dart         # Reusable layer popover card (4 rows, active highlighted)
      search_modal.dart          # Nominatim search — fade-in full-screen modal
      waypoint_markers.dart      # WaypointMarkersOverlay — custom circle symbols via addImage()
      route_polyline.dart        # RoutePolylineOverlay — addLine() annotation
    routes/
      route_editor_screen.dart   # Editor: long-press, drag, undo/redo, snap toggle, layer popover
      editor_stats_sheet.dart    # DraggableScrollableSheet: name, elevation chart, colors, pace, save/delete
      route_list_sheet.dart      # Always-peeking bottom sheet with route rows + GPX import button
      route_list_modal.dart      # savedRoutesProvider (FutureProvider<List<SavedRoute>>)
      route_detail_modal.dart    # Fade-in floating modal: name, stats, Edit/Export
    elevation/
      elevation_profile.dart     # fl_chart elevation with scrub marker + tap-to-fly callback
    gpx/
      gpx_parser.dart            # parseGpx() → List<Waypoint>
      gpx_exporter.dart          # exportGpx() → GPX 1.1 XML string
    auth/
      sign_in_sheet.dart         # Bottom sheet: sign-in / forgot-password / register modes
    settings/
      settings_screen.dart       # Full-screen: units toggle, layer dropdown, account section
    sync/
      sync_service.dart          # SyncService.sync() — push + pull + settings; syncService singleton
```

---

## Providers — Quick Reference

| Provider | Type | Purpose |
|---|---|---|
| `routeProvider` | `NotifierProvider<RouteNotifier, RouteState>` | All in-editor state (waypoints, route geometry, elevation, undo/redo) |
| `routingProvider` | Notifier | Triggers Valhalla fetch; writes back to `routeProvider` |
| `savedRoutesProvider` | `FutureProvider<List<SavedRoute>>` | Route list from SQLite; invalidate after any write |
| `settingsProvider` | `AsyncNotifierProvider<SettingsNotifier, SettingsState>` | unitSystem + defaultLayer; reads SQLite async |
| `activeLayerProvider` | `StateProvider<MapLayer?>` | Current session map layer; null → falls back to settings default → trail |
| `authUserProvider` | `StreamProvider<User?>` | Supabase auth stream; null = signed out |
| `authNotifierProvider` | `NotifierProvider<AuthNotifier, AsyncValue<void>>` | signIn / register / signOut / resetPassword |

---

## Domain Model

```dart
Waypoint { id: String, latitude, longitude, label: String (A/B/C…), snapAfter: bool }
RouteStats { distanceKm, gainM, lossM }
SavedRoute { id: int, remoteId: String?, name, color: hex, waypoints, geometry: GeoJSON, stats,
             createdAt, updatedAt, deletedAt }
RouteState { editingMode, waypoints, history[][], future[][], route: GeoJSON?,
             elevationData[][], routeStats, isSnapping, isLoading, focusCoordinate,
             elevationMarkerCoord, activeRouteId, routeColor, editingRouteName }
SettingsState { unitSystem: 'metric'|'imperial', defaultLayer: MapLayer }
```

---

## SQLite Schema

```sql
routes(id INTEGER PK, remote_id TEXT, name TEXT, color TEXT, waypoints TEXT,
       geometry TEXT, stats TEXT, created_at TEXT, updated_at TEXT, deleted_at TEXT)
settings(key TEXT PK, value TEXT, updated_at TEXT)
-- Default row on create: ('unit_system', 'metric')
-- Also used: ('default_layer', 'trail')
```

Supabase tables: `routes` (UUID PK, user_id, same columns as local), `user_settings` (user_id + key PK).

---

## Key Patterns

**Map style switching:**
```dart
_mapController?.setStyleString(layer.styleUrl);
// On onStyleLoadedCallback, increment _styleVersion and pass as key to overlay widgets
// so WaypointMarkersOverlay re-registers addImage() custom bitmaps.
```

**Layer popover positioning (Stack):**
```dart
// Dismiss underlay first, then popover on top
if (_showLayerPopover) Positioned.fill(GestureDetector(onTap: dismiss, translucent))
if (_showLayerPopover) SafeArea(Align(topRight, Padding(right: 54, top: 8, child: LayerPopover(…))))
// right: 54 = button width (42) + outer padding (8) + gap (4)
```

**Reading settings safely (async):**
```dart
ref.watch(settingsProvider).value?.isImperial ?? false
```

**Sync trigger after sign-in:**
```dart
final signedIn = await showModalBottomSheet<bool>(…SignInSheet…);
if (signedIn == true) await syncService.sync();
```

**Invalidate route list after writes:**
```dart
ref.invalidate(savedRoutesProvider);
```

---

## Conventions

- File names: `snake_case.dart`
- Class names: `PascalCase`
- No `BuildContext` passed into services — use `ref` in providers
- All SQLite queries use positional `?` params, never string interpolation
- `updated_at` set by app on every write
- All reads filter `WHERE deleted_at IS NULL` (except `listRoutesAll` for sync)

---

## Key Commands

```bash
flutter doctor          # verify dependencies
flutter pub get         # install packages
flutter run --dart-define=STADIA_API_KEY=xxx --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
flutter build apk --release --split-per-abi
flutter clean           # fix most weird build errors
```

---

## Environment Variables (passed via --dart-define)

```
STADIA_API_KEY      # map tiles
SUPABASE_URL        # cloud sync / auth
SUPABASE_ANON_KEY   # cloud sync / auth
```

Read in Dart: `const String.fromEnvironment('STADIA_API_KEY')`

---

## Documentation Maintenance

| Change | Update |
|---|---|
| New feature added | `docs/features.md` + Phase Status table above |
| New package | `docs/framework-notes/flutter.md` Packages table |
| Schema change | `docs/architecture.md` + `lib/services/db.dart` |
| MapLibre pattern discovered | `docs/framework-notes/flutter.md` |
| New Android permission | `android/app/src/main/AndroidManifest.xml` + `docs/setup-android.md` |

---

## Docs

- `docs/features.md` — full UX spec (tech-agnostic, acceptance checklist)
- `docs/architecture.md` — domain model, routing logic, sync strategy
- `docs/api-contract.md` — Valhalla API shape, GPX format, Supabase schema
- `docs/evaluation.md` — per-feature completion table + DX notes
- `docs/framework-notes/flutter.md` — Flutter-specific patterns and gotchas
