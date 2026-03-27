# routeapp — CLAUDE.md

> Global rules (workflow, git, TypeScript, Biome) are in `/c/web/CLAUDE.md`. This file covers what's shared across all three framework implementations.

## Project Overview

Multi-framework Android app evaluation. The same hiking route planner (waypoints, trail-snapped routing via Stadia Valhalla, GPX import/export, elevation profiles, Supabase sync) is implemented in three stacks to determine the best framework for personal Android development going forward.

Each implementation lives in its own subfolder with its own CLAUDE.md extending these rules.

## Implementations
- `flutter/` — Flutter + Dart + `maplibre_gl`
- `tauri/` — Tauri 2 Android + React + TypeScript + MapLibre GL JS
- `kotlin/` — Kotlin + Jetpack Compose + `maplibre-compose`

## Shared Domain Model

```
Waypoint
  id:          UUID string
  latitude:    float
  longitude:   float
  label:       string (A, B, C…)
  snapAfter:   bool (trail-snap this segment from previous waypoint)

Route
  id:          local integer primary key
  remoteId:    UUID (Supabase) or null
  name:        string
  color:       hex string (default #3b82f6)
  waypoints:   JSON array of Waypoint
  geometry:    GeoJSON LineString (all legs concatenated)
  stats:       RouteStats or null
  createdAt:   ISO 8601 timestamp
  updatedAt:   ISO 8601 timestamp
  deletedAt:   ISO 8601 timestamp or null (soft delete)

RouteStats
  distanceKm:  float
  gainM:       float (elevation gain in metres)
  lossM:       float (elevation loss in metres)

ElevationPoint
  distanceKm:  float (cumulative distance along route)
  elevationM:  float
```

## SQLite Schema

```sql
CREATE TABLE routes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id   TEXT,
  name        TEXT    NOT NULL,
  color       TEXT    NOT NULL DEFAULT '#3b82f6',
  waypoints   TEXT    NOT NULL,  -- JSON
  geometry    TEXT    NOT NULL,  -- GeoJSON
  stats       TEXT,              -- JSON or NULL
  created_at  TEXT    NOT NULL,
  updated_at  TEXT    NOT NULL,
  deleted_at  TEXT               -- soft delete
);

CREATE TABLE settings (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
```

Always filter `WHERE deleted_at IS NULL` on every read. `updated_at` is set by the application on every write (no DB trigger available in SQLite across frameworks).

## Stadia / Valhalla API

Base URL: `https://valhalla1.openstreetmap.de` (public) or Stadia endpoint with key.

**Route endpoint:** `POST /route/v1?api_key=KEY`
```json
{
  "locations": [{"lon": 0, "lat": 0, "type": "break"}],
  "costing": "pedestrian",
  "costing_options": {
    "pedestrian": { "use_trails": 1.0, "walking_speed": 5.1 }
  },
  "directions_type": "none"
}
```
Response: `trip.legs[].shape` (polyline6-encoded), `trip.summary.length` (km).

**CRITICAL:** Valhalla encodes at precision 1e6 (polyline6), NOT 1e5 (standard Google polyline). Every implementation must use the correct precision when decoding.

**Elevation endpoint:** `POST /elevation/v1?api_key=KEY`
```json
{ "shape": [{"lon": 0, "lat": 0}], "range": true }
```
Response: `range_height` — array of `[distanceMetres, elevationMetres]` pairs.
Normalise distance to km: `distanceKm = distanceMetres / 1000`.

**Snap to trails:** `use_trails: 1.0` = snap; `use_trails: 0.5` = no snap (per-segment in advanced mode).

## Feature Checklist (implement in order)

1. [ ] Map view — MapLibre + Stadia raster tiles
2. [ ] Long-press to drop waypoints (labeled A, B, C…)
3. [ ] Valhalla routing between waypoints (debounced on change)
4. [ ] Draggable waypoint markers
5. [ ] Snap-to-trail toggle
6. [ ] Elevation profile chart with tap-to-fly camera
7. [ ] GPX import via file picker
8. [ ] GPX export via system share sheet
9. [ ] Route save/load (SQLite)
10. [ ] Route list view
11. [ ] Center map on GPS location
12. [ ] Supabase auth
13. [ ] Cloud sync push/pull

## Evaluation Criteria

Track in `docs/evaluation.md` after completing each feature:
- **Map rendering quality** — trail detail, marker smoothness, frame rate
- **Claude effectiveness** — first-attempt accuracy, back-and-forth required
- **Build simplicity** — setup time, hot reload, release APK effort
- **Feature completeness** — items completed and relative effort

## Environment Variables

All implementations share these keys (reuse from existing projects):
```
STADIA_API_KEY   # from Route-builder .env (EXPO_PUBLIC_STADIA_KEY)
SUPABASE_URL     # from betaapp
SUPABASE_ANON_KEY # from betaapp
```

## Version Control

Single repo. Branch naming:
- `feat/flutter-<feature>` — Flutter work
- `feat/tauri-<feature>` — Tauri work
- `feat/kotlin-<feature>` — Kotlin work
- `phase/<n>-<description>` — phase milestones

GitHub: `sethgo88/routeapp`

## Docs
- `docs/architecture.md` — full feature design + sync strategy
- `docs/api-contract.md` — Valhalla + Supabase + GPX format details
- `docs/evaluation.md` — running comparison notes per framework
- `docs/setup-android.md` — Windows 11 Android prereqs (shared)
- `docs/framework-notes/flutter.md` — Flutter lessons + patterns
- `docs/framework-notes/tauri.md` — Tauri Android lessons + patterns
- `docs/framework-notes/kotlin.md` — Kotlin/Compose lessons + patterns
