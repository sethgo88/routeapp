---
paths:
  - "flutter/lib/**"
---

## Flutter Patterns

### State (Riverpod)
- Use `StateNotifierProvider<RouteNotifier, RouteState>` for all mutable route state.
- Expose read-only state with `ref.watch(routeProvider)`.
- Mutate via `ref.read(routeProvider.notifier).methodName(...)`.
- Use `AsyncNotifierProvider` for async data that can be invalidated. Never use
  `FutureProvider` for data that needs explicit invalidation.
- No `BuildContext` passed into services or notifiers — use `ref`.

### SQLite (sqflite)
- All queries use positional `?` params — never string interpolation.
- Always filter `WHERE deleted_at IS NULL` on every read query.
- `updated_at` is set by the app layer on every write (no DB triggers in sqflite).
- Database init lives in `services/db.dart`. Use `openDatabase` with `onCreate` and
  `onUpgrade` callbacks for migrations.

### Naming
- Files: `snake_case.dart`
- Classes, enums, typedefs: `PascalCase`
- Variables, params, methods: `camelCase`
- Private members: `_camelCase`

### Async
- Use `async`/`await` throughout. Never use `.then()` chaining.
- Wrap Valhalla calls and DB writes in try/catch; surface errors through notifier state.

### MapLibre controller
- Obtain via `onMapCreated(MaplibreMapController controller)` callback.
- Store controller in the widget's state; null-check before use.
- All map mutations (`addSymbol`, `addLine`, `updateSymbol`) are `await`-ed.
