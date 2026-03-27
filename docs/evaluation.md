# Framework Evaluation

Running notes comparing Flutter, Tauri 2 Android, and Kotlin/Compose implementations.

## Scoring Criteria

Rate each criterion 1–5 after completing the full feature checklist:

| Criterion | Weight | Description |
|---|---|---|
| Map rendering quality | High | Trail detail, marker smoothness, frame rate during pan/zoom |
| Claude effectiveness | High | % of code written correctly on first attempt; back-and-forth required |
| Build simplicity | Medium | Windows 11 setup time, hot reload DX, release APK effort |
| Feature completeness | Medium | Checklist items completed and relative difficulty |

---

## Flutter

**Setup date:** 2026-03-27
**Setup time:** Phase 1 complete

### Feature progress
| Feature | Done | Notes |
|---|---|---|
| Map view (MapLibre + Stadia) | ✓ | Stadia outdoors style, full screen |
| Waypoint drop (long-press) | ✓ | Long-press on editor map |
| Valhalla routing | ✓ | Segmented per-waypoint snap, debounced 600ms |
| Draggable markers | ✓ | MapLibre symbol API with drag |
| Snap toggle | ✓ | Per-waypoint snapAfter flag, magnet icon in editor |
| Elevation chart + tap-to-fly | ✓ | Index-based cross-ref to route coords; tap flies camera |
| GPX import | ✓ | File picker → editor with imported waypoints |
| GPX export | ✓ | Android share intent via share_plus |
| SQLite save/load | ✓ | sqflite, soft deletes, color + stats stored |
| Route list | ✓ | Always-peeking bottom sheet on home map |
| GPS centering | ✓ | geolocator with permission request |
| Map layer switcher | ✓ | Popover with 4 Stadia styles; active layer persisted to SQLite |
| Search (geocoding) | ✓ | Nominatim-backed; fade-in modal; tap pans map |
| Settings screen | ✓ | Units toggle (km/mi/m/ft), default layer dropdown, account section |
| Supabase auth | ✓ | Email/password sign in, register, forgot password, sign out |
| Cloud sync | ✓ | Push/pull on sign-in; unit_system synced to user_settings table |
| Unit-aware display | ✓ | All distance/elevation displays respect metric/imperial toggle |
| Offline tile download | ✓ | Bbox selection screen, draggable corners, size estimate, maplibre_gl offline API |
| Downloaded regions sheet | ✓ | List, View (zoom to bounds), Delete with confirmation |

### DX Notes
- Phase 1 implemented by Claude on first pass. Home map / editor split required a full UI redesign from the initial scaffold.
- `maplibre_gl` symbol API works for draggable markers; custom bitmaps via `ui.PictureRecorder` give colored circles matching spec.
- `DraggableScrollableSheet` with `snap: true` + `snapSizes` works cleanly for both the route list sheet and editor stats sheet.
- `queryRenderedFeatures` on line layers enables route tap detection on home map.
- Elevation tap-to-fly works because the elevation API returns one point per input coordinate (1:1 index mapping to route geometry).
- Phase 3: `maplibre_gl` offline API (`downloadOfflineRegion`, `getListOfRegions`, `deleteOfflineRegion`) are top-level functions exported from the package. `OfflineRegionDefinition` takes `double` zoom levels. Size is estimated via tile-count formula (~15 KB/tile for vector tiles).
- Bbox selection screen uses screen-space `Offset` coordinates for the rectangle; corners are converted to `LatLng` via `controller.toLatLng(Point<double>)` only on drag-end and on save.
- `DraggableScrollableController` enables collapsing the regions sheet to peek when "View" is tapped.

### Build Notes
_To be filled after first device test._

### Map Rendering Notes
_To be filled after first device test._

---

## Tauri 2 Android

**Setup date:** _
**Setup time:** _

### Feature progress
| Feature | Done | Notes |
|---|---|---|
| Map view (MapLibre GL JS + Stadia) | | |
| Waypoint drop (long-press) | | |
| Valhalla routing | | |
| Draggable markers | | |
| Snap toggle | | |
| Elevation chart + tap-to-fly | | |
| GPX import | | |
| GPX export | | |
| SQLite save/load | | |
| Route list | | |
| GPS centering | | |
| Supabase auth | | |
| Cloud sync | | |

### DX Notes
_How well did the TypeScript/React approach work? WebView friction? Tauri Android quirks?_

### Build Notes
_NDK setup, env vars, build times, APK size._

### Map Rendering Notes
_WebGL MapLibre performance vs native, any visual differences._

---

## Kotlin + Compose

**Setup date:** _
**Setup time:** _

### Feature progress
| Feature | Done | Notes |
|---|---|---|
| Map view (maplibre-compose + Stadia) | | |
| Waypoint drop (long-press) | | |
| Valhalla routing | | |
| Draggable markers | | |
| Snap toggle | | |
| Elevation chart + tap-to-fly | | |
| GPX import | | |
| GPX export | | |
| SQLite save/load (Room) | | |
| Route list | | |
| GPS centering | | |
| Supabase auth | | |
| Cloud sync | | |

### DX Notes
_Kotlin learning curve, Claude Compose support, Android Studio vs VS Code._

### Build Notes
_Gradle setup, build times, APK size._

### Map Rendering Notes
_Native MapLibre performance, maplibre-compose API stability._

---

## Final Comparison

_Fill in after all three are complete._

| | Flutter | Tauri | Kotlin |
|---|---|---|---|
| Map rendering | /5 | /5 | /5 |
| Claude effectiveness | /5 | /5 | /5 |
| Build simplicity | /5 | /5 | /5 |
| Feature completeness | /5 | /5 | /5 |
| **Total** | **/20** | **/20** | **/20** |

**Winner:** _

**Recommendation for future apps:** _
