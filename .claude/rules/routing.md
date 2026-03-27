---
paths:
  - "*/features/routing/**"
  - "*/routing/**"
---

## Routing Rules (Valhalla)

- **polyline6 precision** — Valhalla encodes at `1e6`, NOT the standard Google `1e5`.
  Every decoder must pass `1e6` as the precision constant. This is the single most
  common bug in new implementations.
- **Decoded coordinate order** — Valhalla returns `[lat, lon]`. Flip to `[lon, lat]`
  for GeoJSON / MapLibre.
- **Multi-leg concatenation** — multi-waypoint routes return one leg per segment.
  Concatenate legs but skip the duplicate junction point: `legs[n].coords.slice(1)`
  for every leg after the first.
- **600 ms debounce** — debounce all routing fetches 600 ms after the last waypoint
  change. This covers drag operations without hammering the API.
- **Three editing modes** — `view` (idle), `creating` (new route), `editing` (saved
  route loaded). Only `creating` and `editing` trigger routing. Routing state lives in
  the route store/provider, not in the map component.
- **Snap modes** — `use_trails: 1.0` for trail-snap, `use_trails: 0.5` for no snap.
  The per-waypoint `snapAfter` field controls which value is sent for each segment.
- **Elevation endpoint** — always send the full concatenated route shape (not
  individual legs) to `POST /elevation/v1`. Divide `range_height[i][0]` by 1000 to
  get km.
- **Costing** — always `"costing": "pedestrian"` with `"directions_type": "none"`.
