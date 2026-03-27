# Tauri 2 Android Notes

Framework-specific lessons, patterns, and gotchas for the Tauri Android implementation.

> See also `/c/web/docs/tauri.md` for general Tauri 2 guidance.

## How Tauri Android Works

Same architecture as desktop Tauri — React/TypeScript frontend rendered in a WebView, Rust backend for native access. On Android, the WebView is the system Chromium WebView (not bundled). MapLibre GL JS runs in this WebView using WebGL, which is fully supported.

The frontend code is **identical** to a web app. The only difference is accessing native APIs (GPS, file system) via Tauri plugins instead of browser APIs.

## Setup (Windows 11)

In addition to Android Studio + SDK (see `docs/setup-android.md`), Tauri Android requires:

**1. Rust + Android targets:**
```bash
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add i686-linux-android
rustup target add x86_64-linux-android
```

**2. NDK (installed via Android Studio SDK Manager → NDK Side by Side)**

**3. Environment variables (set in Windows, reboot after):**
```
NDK_HOME = %ANDROID_HOME%\ndk\<version>  (e.g. 27.2.12479018)
WRY_ANDROID_PACKAGE = com.routeapp.tauri
WRY_ANDROID_LIBRARY = routeapp_tauri
WRY_ANDROID_KOTLIN_FILES_OUT_DIR = <absolute-path-to-tauri-project>/gen/android
```

**4. Initialize Android project:**
```bash
pnpm tauri android init
```

## Key Commands

```bash
pnpm dev                        # Vite dev server only
pnpm tauri android dev          # dev with hot reload on device
pnpm tauri android build --apk  # debug APK
pnpm tauri android build --apk --release  # signed release APK
pnpm tauri android build        # AAB for Play Store
```

## Required Tauri Plugins

```toml
# src-tauri/Cargo.toml
tauri-plugin-geolocation = "2"
tauri-plugin-fs = "2"
tauri-plugin-dialog = "2"
tauri-plugin-sql = { version = "2", features = ["sqlite"] }
```

```bash
pnpm add @tauri-apps/plugin-geolocation @tauri-apps/plugin-fs @tauri-apps/plugin-dialog @tauri-apps/plugin-sql
```

## MapLibre GL JS in WebView

```typescript
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

const map = new maplibregl.Map({
  container: 'map',
  style: `https://tiles.stadiamaps.com/styles/outdoors.json?api_key=${STADIA_KEY}`,
  center: [-122.4194, 37.7749],
  zoom: 12,
});
```

Long-press on mobile: use `touchstart`/`touchend` with a timer (no native long-press event in WebGL canvas):
```typescript
let pressTimer: ReturnType<typeof setTimeout>;
map.on('touchstart', (e) => {
  pressTimer = setTimeout(() => addWaypoint(e.lngLat), 500);
});
map.on('touchend', () => clearTimeout(pressTimer));
map.on('touchmove', () => clearTimeout(pressTimer));
```

## CSP (tauri.conf.json)

The WebView needs CSP allowances for Stadia tile servers:

```json
"security": {
  "csp": "default-src 'self'; connect-src 'self' https://*.stadiamaps.com wss://*.stadiamaps.com https://*.supabase.co wss://*.supabase.co; img-src 'self' data: blob: https://*.stadiamaps.com; worker-src blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
}
```

## GPS Plugin

```typescript
import { getCurrentPosition, watchPosition } from '@tauri-apps/plugin-geolocation';

const pos = await getCurrentPosition({ enableHighAccuracy: true });
// pos.coords.latitude, pos.coords.longitude
```

## File I/O

GPX export via dialog plugin (prompts user for save location):
```typescript
import { save } from '@tauri-apps/plugin-dialog';
import { writeTextFile } from '@tauri-apps/plugin-fs';

const path = await save({ filters: [{ name: 'GPX', extensions: ['gpx'] }] });
if (path) await writeTextFile(path, gpxString);
```

GPX import:
```typescript
import { open } from '@tauri-apps/plugin-dialog';
import { readTextFile } from '@tauri-apps/plugin-fs';

const path = await open({ filters: [{ name: 'GPX', extensions: ['gpx'] }] });
if (path) {
  const contents = await readTextFile(path as string);
  // parse XML...
}
```

## Known Issues (as of Tauri 2.8–2.9)

- `versionName` and `versionCode` don't read from `tauri.conf.json` (defaults to 1.0/1)
- `targetSdk` bug in some RC versions caused "built for older Android" warnings
- `tauri android dev` hot reload can be slow to connect on first launch

## Gotchas

_Fill in as discovered during implementation._
