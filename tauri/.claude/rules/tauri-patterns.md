---
paths:
  - "tauri/src/**"
---

## Tauri Patterns (mirrors betaapp)

### Zustand selectors
- Always select the minimal slice needed to avoid unnecessary re-renders on the map
  (the map is always mounted).
- Pattern: `const waypoints = useRouteStore((s) => s.waypoints)` — not
  `const store = useRouteStore()`.
- Actions are selected separately: `const addWaypoint = useRouteStore((s) => s.addWaypoint)`.

### TanStack Query
- All async data fetching (routes list, Supabase reads) uses `useQuery`/`useMutation`.
  No `useEffect` for data fetching.
- Query keys: `['routes']` for the list, `['route', id]` for a single route.
- After a mutation (save/delete), call `queryClient.invalidateQueries({ queryKey: ['routes'] })`.

### DB access
- All SQL goes through `src/lib/db.ts` (`getDb().select(...)` / `getDb().execute(...)`).
  Never import `@tauri-apps/plugin-sql` directly in feature code.
- Use positional `?` params in all queries — never string interpolation.

### Zod v4
- Use `.safeParse()` directly in TanStack Form validators — no zod-form-adapter.
- Schema files live alongside feature code: `routes.schema.ts`, `gpx.schema.ts`.

### MapLibre GL JS lifecycle
- Create the map in a `useEffect` with an empty deps array.
- Return `() => map.remove()` from that same effect to destroy on unmount.
- Store the map instance in a `useRef`, not in state.
- Update GeoJSON source data with `map.getSource('route')?.setData(geojson)` — do not
  call `addSource`/`addLayer` again on every update.
