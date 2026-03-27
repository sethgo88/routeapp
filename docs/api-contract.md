# API Contract

Canonical reference for all external API shapes used across routeapp implementations.

## Stadia Maps

**Tile URL (raster, for map background):**
```
https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}{r}.png?api_key=KEY
```
Other useful styles: `alidade_smooth`, `alidade_smooth_dark`, `outdoors` (best for hiking).

**Base URL:** `https://valhalla1.openstreetmap.de` (no key required) OR `https://valhalla.stadiamaps.com` (API key required for higher rate limits).

---

## Valhalla Routing

### Route Request
`POST /route/v1?api_key=KEY`

```json
{
  "locations": [
    { "lon": -122.4194, "lat": 37.7749, "type": "break" },
    { "lon": -122.4094, "lat": 37.7849, "type": "break" }
  ],
  "costing": "pedestrian",
  "costing_options": {
    "pedestrian": {
      "use_trails": 1.0,
      "walking_speed": 5.1
    }
  },
  "directions_type": "none"
}
```

- `use_trails: 1.0` = strongly prefer trails; `use_trails: 0.5` = neutral; `use_trails: 0.0` = avoid trails
- `walking_speed`: km/h, used for time estimates (not critical for our use case)

### Route Response
```json
{
  "trip": {
    "legs": [
      { "shape": "<polyline6-encoded-string>" }
    ],
    "summary": {
      "length": 4.32
    }
  }
}
```

- `summary.length` is in **kilometres**
- `legs[].shape` is **polyline6** encoded (precision **1e6**, NOT 1e5)
- Multi-waypoint routes return one leg per segment. Concatenate legs, skipping the duplicate junction point: `leg[n].coords.slice(1)` for all legs after the first.

### Polyline6 Decoding
Standard Google polyline uses `1e5`. Valhalla uses `1e6`. The algorithm is identical but the precision constant differs. Decoded coordinate order is `[lat, lon]` — **flip to `[lon, lat]` for GeoJSON**.

### Elevation Request
`POST /elevation/v1?api_key=KEY`

```json
{
  "shape": [
    { "lon": -122.4194, "lat": 37.7749 },
    { "lon": -122.415, "lat": 37.778 }
  ],
  "range": true
}
```

### Elevation Response
```json
{
  "range_height": [
    [0, 15.2],
    [120.4, 18.7],
    [305.1, 22.1]
  ]
}
```

- `range_height[i]` = `[distanceMetres, elevationMetres]`
- Divide distance by 1000 to get km for the chart: `distanceKm = distanceMetres / 1000`
- Last entry's distance / 1000 = total route length in km

---

## GPX Format

Route Builder exports GPX 1.1 with track points that include elevation.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="routeapp"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>Route Name</name>
    <time>2026-03-26T12:00:00Z</time>
  </metadata>
  <trk>
    <name>Route Name</name>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194">
        <ele>15.2</ele>
      </trkpt>
      <!-- ...more trkpt elements... -->
    </trkseg>
  </trk>
</gpx>
```

**Import rules:**
- Parse all `<trkpt>` elements; extract `lat`, `lon` attributes and optional `<ele>` child
- Load as `Coordinate[]` with `snapAfter: false` (straight-line segments; user re-routes as desired)
- Ignore waypoints (`<wpt>`) and route elements (`<rte>`) — only track segments matter

**Export rules:**
- Use the route geometry shape points (not the waypoints), with elevation from `elevationData`
- Match shape points to elevation by index (1:1 correspondence after the Valhalla elevation call)
- If no elevation data, omit `<ele>` elements

---

## Supabase

**Auth:** Email/password. Same project as betaapp.

**Routes table upsert (push):**
```json
{
  "id": "uuid-from-supabase",
  "user_id": "auth-user-uuid",
  "name": "Trail Run",
  "color": "#3b82f6",
  "waypoints": [...],
  "geometry": { "type": "Feature", "geometry": { "type": "LineString", "coordinates": [...] }, "properties": {} },
  "stats": { "distanceKm": 4.32, "gainM": 120, "lossM": 85 },
  "created_at": "2026-03-26T12:00:00Z",
  "updated_at": "2026-03-26T12:00:00Z",
  "deleted_at": null
}
```

**Routes fetch (pull):**
`GET /rest/v1/routes?user_id=eq.UUID&select=*` — returns all routes for current user including soft-deleted ones (so we can propagate deletes).

**Settings upsert:**
```json
{ "user_id": "uuid", "key": "unit_system", "value": "metric", "updated_at": "..." }
```
Use `ON CONFLICT (user_id, key) DO UPDATE`.
