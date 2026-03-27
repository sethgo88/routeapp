# Implementation Phases

Each framework implementation follows the same three phases.
Complete all three phases for one framework before starting another,
or run them in parallel — your call.

---

## Phase 1 — Core map + route editor

The full interactive route-building experience, matching `docs/features.md`
sections 1–5 and 11–15. No auth, no sync, no offline.

| Feature | Spec ref |
|---|---|
| Home map screen (top controls, all saved routes displayed) | §1 |
| Route List Sheet (always-peeking bottom sheet) | §3 |
| Route Detail Modal (tap route on map) | §2 |
| Route Editor (full screen, own map) | §4 |
| Editor Stats Sheet (name, elevation, color swatches, pace, save/delete) | §5 |
| Waypoint interactions (long-press add, drag, tap-select, undo/redo) | §4, §16 |
| Snap-to-trail toggle (per-segment) | §4 |
| Elevation chart + tap-to-fly | §5 |
| Color swatches (17 colors) | §5 |
| GPX import (file picker → editor) | §11 |
| GPX export (Android share intent) | §12 |
| SQLite persistence (save, load, soft delete) | — |
| GPS centering | §1, §4 |
| Unsaved changes guard | §14 |
| Delete confirmation | §13 |

**Flutter status:** ✅ complete (2026-03-27)
**Tauri status:** not started
**Kotlin status:** not started

---

## Phase 2 — Search, settings, auth + sync

Polished app shell and cloud features, matching `docs/features.md` §6–8
and `docs/architecture.md` sync strategy.

| Feature | Spec ref |
|---|---|
| Map Layer Switcher popover (Satellite, Topo, Trail overlay, Street) | §6 |
| Search modal (geocoding, 2+ chars, tap-to-pan) | §7 |
| Settings screen (units toggle km↔mi, default map layer) | §8 |
| Sign In Sheet (email + password, forgot password, register) | §8 |
| Supabase auth (sign in, register, sign out) | §8 |
| Cloud sync (push new routes, pull remote routes, sync deleted) | `docs/architecture.md` |
| Unit display rules (m/km threshold, always m/ft for elevation) | §15 |

**Flutter status:** not started
**Tauri status:** not started
**Kotlin status:** not started

---

## Phase 3 — Offline maps

Tile download and offline region management, matching `docs/features.md` §9–10.

| Feature | Spec ref |
|---|---|
| Downloaded Regions Sheet (list, view bbox, delete) | §9 |
| Bbox Selection screen (draggable corners, estimated size, name + save) | §10 |
| Offline tile download and storage | §9–10 |
| Region delete confirmation | §9 |

**Flutter status:** not started
**Tauri status:** not started
**Kotlin status:** not started
