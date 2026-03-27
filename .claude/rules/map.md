---
paths:
  - "*/features/map/**"
  - "*/map/**"
---

## Map Rules (MapLibre — all frameworks)

- **Tile style URL** — always use the Stadia outdoors style:
  `https://tiles.stadiamaps.com/styles/outdoors.json?api_key=KEY`
  Never hardcode the API key; read it from env/build config.
- **Long-press for waypoints** — long-press (500 ms threshold on touch) is the sole
  mechanism for dropping a new waypoint. Do not add tap-to-place.
- **Polyline source/layer pattern** — represent the route as a GeoJSON LineString source
  with a corresponding line layer. Update the source data in place; do not remove and
  re-add layers on every route change.
- **Editing mode visuals** — route line is solid and full-opacity in view/editing modes.
  While a waypoint is being dragged, the two adjacent segments are replaced by dashed
  straight lines until routing resolves.
- **Map instance lifecycle** — always destroy the map instance on component/widget
  unmount or `onPause` to prevent duplicate-map errors on remount.
  - Flutter: call `controller.dispose()`
  - Tauri: call `map.remove()` in the `useEffect` cleanup
  - Kotlin: follow the `MaplibreMap` composable lifecycle
- **Waypoint marker labels** — start = green, end = red, middle = white with numeric
  label (1, 2, 3…). Selected waypoint gets a yellow glow/halo.
- **All saved routes on home map** — draw all non-deleted routes simultaneously, each
  in its own `routeColor`. Hide all saved routes while the editor is open.
