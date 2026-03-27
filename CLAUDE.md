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

## Domain Rules

Short constraint docs live in `.claude/rules/` — Claude Code loads these automatically
for matching file paths. Read them before touching the relevant code:

| Rule file | Governs |
|---|---|
| `.claude/rules/map.md` | MapLibre: tile URL, long-press, polyline layer, marker visuals |
| `.claude/rules/routing.md` | Valhalla: polyline6 precision, debounce, snap modes |
| `.claude/rules/gpx.md` | GPX 1.1 format, import/export constraints |
| `.claude/rules/sync.md` | Local-first SQLite-first, upsert, soft deletes |

## Documentation Maintenance

Update the relevant doc before closing any task:

| Change | Update |
|---|---|
| Feature added or changed | `docs/features.md` |
| Schema change (SQLite or Supabase) | `docs/architecture.md` |
| API shape change (Valhalla, GPX, Supabase) | `docs/api-contract.md` |
| Framework evaluation note | `docs/evaluation.md` |
| New library or tech choice | Per-framework `docs/framework-notes/<fw>.md` |
| Android setup step | `docs/setup-android.md` |
| Architecture or navigation change | `docs/architecture.md` |

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
