# Architecture

> Shared design for all three routeapp implementations. Framework-specific docs are in `docs/framework-notes/`.

## Overview

routeapp is a local-first Android hiking route planner. The map is the primary UI. Users drop waypoints on a map, the app routes between them using the Stadia Valhalla API, and the result is displayed as a polyline with an elevation chart. Routes are saved locally (SQLite) with optional cloud sync (Supabase).

## Editing Modes

Three modes govern the app's interactive state:

| Mode | Description |
|---|---|
| `view` | Idle. Route list visible. No active waypoints. |
| `creating` | New route being built. Long-press adds waypoints. |
| `editing` | Existing saved route loaded. Waypoints are editable. |

Transitions:
- `view → creating`: tap "New Route" button
- `view → editing`: load a saved route from the list
- `creating → view`: save or discard the new route
- `editing → view`: save changes or discard

## State Shape

```
RouteState
  editingMode:           'view' | 'creating' | 'editing'
  waypoints:             Waypoint[]
  history:               Waypoint[][]    -- undo stack
  future:                Waypoint[][]    -- redo stack
  route:                 GeoJSON LineString | null
  elevationData:         [distanceKm, elevationM][]
  routeStats:            RouteStats | null
  isSnapping:            bool            -- global snap toggle
  isLoading:             bool            -- routing in flight
  focusCoordinate:       [lon, lat] | null  -- elevation tap-to-fly target
  elevationMarkerCoord:  [lon, lat] | null  -- dot shown after fly
  activeRouteId:         int | null      -- ID of route in editing mode
  routeColor:            string (hex)
  editingRouteName:      string
  draggingWaypointIndex: int | null      -- waypoint being dragged
  dragPreviewCoord:      Coordinate | null
  dragPreviewNeighbors:  Coordinate[]
```

## Routing

### Basic routing (all waypoints same snap setting)
All waypoints share the global `isSnapping` toggle. Send all waypoints to Valhalla in a single request.

### Segmented routing (per-waypoint snap)
Each waypoint has a `snapAfter` field (set at add-time from `isSnapping`). Route each adjacent pair independently:
- If `waypoint[i+1].snapAfter == true` → Valhalla pedestrian route
- If `snapAfter == false` → straight line between the two points

Elevation is fetched once for the full concatenated shape.

### Debouncing
Route fetches are debounced ~600ms after the last waypoint change to avoid hammering the API during drag operations.

### Polyline6 Decoding
Valhalla returns route geometry as a polyline6-encoded string (precision 1e6, NOT the standard 1e5). Multi-leg routes concatenate legs, skipping the duplicate junction point between legs.

## GPX Format

Route Builder uses GPX 1.1. Export format:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="routeapp" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>Route Name</name>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194">
        <ele>10.5</ele>  <!-- elevation in metres, if available -->
      </trkpt>
      ...
    </trkseg>
  </trk>
</gpx>
```

Import: parse `<trkpt>` elements into `Coordinate[]`. Load as waypoints with `snapAfter: false` (straight lines; user can re-route).

## Sync Strategy (Local-First)

1. **Push**: For each local route with `remote_id IS NULL`, upsert to Supabase → store returned UUID as `remote_id`.
2. **Pull**: Fetch all routes from Supabase for the current user. For each, if `remote_id` not in local DB, insert it.
3. **Delete**: Soft-delete locally (set `deleted_at`). On next push, upsert the deleted row so Supabase reflects the deletion.
4. **Settings**: `unit_system` (metric/imperial) is synced via a `user_settings` table in Supabase.

Sync is triggered on sign-in and can be manually triggered. No real-time subscription in MVP.

## Supabase Tables

```sql
-- Routes table (per-user, RLS enforced)
CREATE TABLE routes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  name        TEXT NOT NULL,
  color       TEXT NOT NULL DEFAULT '#3b82f6',
  waypoints   JSONB NOT NULL,
  geometry    JSONB NOT NULL,
  stats       JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);

-- Settings table (per-user key-value)
CREATE TABLE user_settings (
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  key         TEXT NOT NULL,
  value       TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key)
);
```

RLS: users can only read/write their own rows.

## Authentication Flow

Email/password auth via Supabase (`supabase_flutter`). Three modes in a single bottom sheet (`SignInSheet`):

| Mode | Action |
|---|---|
| Sign in | `auth.signInWithPassword(email, password)` → pop with `true` → trigger sync |
| Register | `auth.signUp(email, password)` → show "check your email" confirmation |
| Forgot password | `auth.resetPasswordForEmail(email)` → snackbar + pop |

Auth state is exposed as a `StreamProvider<User?>` from `onAuthStateChange`. Widgets react to null (signed out) vs non-null (signed in).

## Settings Persistence

Settings are stored locally in SQLite and optionally synced to Supabase:

```
settings(key TEXT PK, value TEXT, updated_at TEXT)
```

Known keys:
- `unit_system` — `'metric'` (default) or `'imperial'`
- `default_layer` — `'trail'` | `'satellite'` | `'topo'` | `'street'`

On sign-in, `unit_system` is pushed to the Supabase `user_settings` table. The `SettingsNotifier` (AsyncNotifier) loads values in its `build()` method; widgets read with `ref.watch(settingsProvider).value?.isImperial ?? false`.

## Offline Tile Download

Offline map regions are managed entirely through MapLibre's built-in offline API — no custom SQLite tables needed.

### Flow
1. User opens Settings → Downloaded Regions → "Download region"
2. **Bbox Selection Screen** — full-screen map with a draggable rectangle overlay
   - Rectangle is tracked in screen-space `Offset` coordinates (not LatLng)
   - Four corner dots respond to long-press + drag; `GestureDetector.onLongPressMoveUpdate` moves corners
   - Corners are converted to `LatLng` via `controller.toLatLng(Point<double>)` on drag-end and save
   - Real-time size estimate: tile-count formula across zoom levels 5–14, ~15 KB/tile
3. On save: `downloadOfflineRegion(OfflineRegionDefinition(...), metadata: {name, estimatedSizeMB}, onEvent: callback)`
4. Progress reported via `DownloadRegionStatus` stream (`InProgress`, `Error`, `Success`)

### Region Storage
MapLibre stores tiles internally. Region metadata (name, estimated size) is passed as a `Map<String, dynamic>` metadata argument and retrieved via `OfflineRegion.metadata`.

### Region Management
- **List**: `getListOfRegions()` → `List<OfflineRegion>` → wrapped as `OfflineRegionInfo`
- **View**: collapse sheet to peek, zoom map to `region.bounds`
- **Delete**: `deleteOfflineRegion(region.id)` with confirmation dialog

### OfflineRegionDefinition
```dart
OfflineRegionDefinition(
  bounds: LatLngBounds(southwest: sw, northeast: ne),
  mapStyleUrl: activeLayer.styleUrl,
  minZoom: 5,
  maxZoom: 14,
  pixelDensity: 1,
)
```

## Component / Screen Structure

```
App
└── MapScreen (main, always visible)
    ├── MapView (MapLibre)
    │   ├── WaypointMarkers (draggable)
    │   ├── MidpointMarkers (insert waypoint)
    │   └── RoutePolyline (per segment)
    ├── ControlsPanel (bottom sheet)
    │   ├── RouteStats
    │   ├── SnapToggle
    │   └── ActionButtons (GPX, save, delete, undo/redo)
    ├── ElevationProfile (chart)
    ├── RouteActionBar (save/discard when creating/editing)
    ├── LayerPopover (map style switcher)
    ├── SearchModal (Nominatim geocoding)
    ├── DownloadedRegionsSheet (offline regions list, View/Delete)
    ├── Modals
    │   ├── RouteListModal
    │   ├── NameRouteModal
    │   ├── SignInSheet (auth: sign-in / register / forgot password)
    │   └── UnsavedChangesModal
    ├── SettingsScreen (push navigation)
    │   ├── Units toggle (km↔mi)
    │   ├── Default layer dropdown
    │   └── Account section (sign in / sync / sign out)
    └── BboxSelectionScreen (push navigation)
        ├── Draggable bbox rectangle (4 corner dots)
        ├── Size estimate display
        └── Name input + download button

```

## Navigation Pattern

Single-screen app. All modals/panels are overlaid on the map. No navigation stack. Back button (Android) should:
- Close open modal if one is open
- Prompt UnsavedChangesModal if in creating/editing mode with waypoints
- Exit app otherwise
