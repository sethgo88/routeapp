---
paths:
  - "*/features/gpx/**"
  - "*/gpx/**"
---

## GPX Rules

- **GPX 1.1 only** — use namespace `http://www.topografix.com/GPX/1/1`.
  Do not produce GPX 1.0.
- **lat/lon as attributes** — coordinates are attributes on `<trkpt>`, not child
  elements: `<trkpt lat="37.7749" lon="-122.4194">`.
- **ISO 8601 timestamps** — `<time>` elements must be UTC with Z suffix:
  `2026-03-26T12:00:00Z`. Do not use local time.
- **Export from geometry, not waypoints** — export uses the route geometry shape points
  (the Valhalla-decoded coordinates), not the user's dropped waypoints. Elevation from
  `elevationData` is matched by index (1:1 correspondence). Omit `<ele>` if no
  elevation data exists.
- **Import: track points only** — parse `<trkpt>` elements only. Ignore `<wpt>` and
  `<rte>` elements. Load as `Coordinate[]` with `snapAfter: false`.
- **Required field validation** — reject import if `lat` or `lon` attributes are
  missing or non-numeric on any `<trkpt>`. Surface a user-visible error; do not
  silently drop points.
- **Creator attribute** — always set `creator="routeapp"` on the root `<gpx>` element.
