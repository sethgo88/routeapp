# routeapp/tauri — CLAUDE.md

> Global rules: `/c/web/CLAUDE.md`. Shared domain/API/feature rules: `/c/web/routeapp/CLAUDE.md`. This file covers Tauri Android-specific conventions only.

## Stack
Tauri 2, React 19, TypeScript strict, Vite, Tailwind CSS 4, Biome, TanStack Query, TanStack Form, Zustand, Zod v4, MapLibre GL JS, `@tauri-apps/plugin-geolocation`, `@tauri-apps/plugin-fs`, `@tauri-apps/plugin-dialog`, `@tauri-apps/plugin-sql`

Mirrors the betaapp/moviedb stack exactly. Reference `/c/web/betaapp/tauri/betaapp/` for patterns.

## Key Commands
```bash
pnpm install
pnpm dev                           # Vite dev server only
pnpm tauri android dev             # dev with hot reload on device
pnpm tauri android build --apk     # debug APK
pnpm tauri android build --apk --release  # release APK
pnpm tauri android build           # AAB for Play Store
pnpm lint                          # biome check .
pnpm typecheck                     # tsc --noEmit
pnpm format                        # biome format --write .
```

## Folder Structure
```
src/
  features/
    map/          # MapLibre GL JS component, long-press, markers, polylines
    routing/      # Valhalla fetch, useRouting hook (TanStack Query)
    routes/       # SQLite CRUD, route list, useRoutes hook
    gpx/          # GPX parser + exporter
    elevation/    # Elevation chart (SVG or chart lib)
    auth/         # Supabase auth
    sync/         # Cloud sync service
  store/
    routeStore.ts     # Zustand — all active editing state (mirrors Route-builder)
    authStore.ts
    settingsStore.ts
  lib/
    supabase.ts   # Supabase client
    db.ts         # SQL plugin wrapper
  constants/
    map.ts        # API keys, tile URLs, Valhalla base URL
src-tauri/
  tauri.conf.json
  Cargo.toml
  src/
    lib.rs
    main.rs
```

## Conventions
- Mirrors betaapp exactly: same atomic component structure, same TanStack Query patterns, same Zod v4 `.safeParse()`
- No `useEffect` for data fetching — TanStack Query only
- Zustand selectors to avoid unnecessary re-renders (map is always visible)
- Long-press: use `touchstart`/`touchend` with 500ms timer (no native WebGL long-press)
- MapLibre GL JS canvas fills the full screen; all UI overlaid with absolute positioning

## MapLibre GL JS
- CDN or npm: `pnpm add maplibre-gl`
- Style: `https://tiles.stadiamaps.com/styles/outdoors.json?api_key=${STADIA_KEY}`
- Container: `<div id="map" style="width:100%;height:100vh"/>` with `ref`

## CSP (tauri.conf.json)
```json
"csp": "default-src 'self'; connect-src 'self' https://*.stadiamaps.com wss://*.stadiamaps.com https://*.supabase.co wss://*.supabase.co; img-src 'self' data: blob: https://*.stadiamaps.com; worker-src blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
```

## Environment
```
VITE_STADIA_KEY=...
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

## Setup Prerequisites
See `docs/setup-android.md` (Android Studio, SDK) and `docs/framework-notes/tauri.md` (Rust targets, NDK, env vars).

## Docs
- `docs/framework-notes/tauri.md` — Tauri Android setup, plugins, known issues
- `/c/web/docs/tauri.md` — General Tauri 2 guide
- `docs/architecture.md` — shared domain model
- `docs/api-contract.md` — Valhalla API, GPX format, Supabase schema
