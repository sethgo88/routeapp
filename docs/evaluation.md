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

**Setup date:** _
**Setup time:** _

### Feature progress
| Feature | Done | Notes |
|---|---|---|
| Map view (MapLibre + Stadia) | | |
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
_Observations about Claude effectiveness, Dart/Flutter friction, hot reload, etc._

### Build Notes
_Setup steps that were tricky, commands used, any Windows 11 gotchas._

### Map Rendering Notes
_Subjective quality, performance observations._

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
