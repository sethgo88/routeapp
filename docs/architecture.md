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
    └── Modals
        ├── RouteListModal
        ├── NameRouteModal
        ├── AccountModal (auth)
        └── UnsavedChangesModal

```

## Navigation Pattern

Single-screen app. All modals/panels are overlaid on the map. No navigation stack. Back button (Android) should:
- Close open modal if one is open
- Prompt UnsavedChangesModal if in creating/editing mode with waypoints
- Exit app otherwise
