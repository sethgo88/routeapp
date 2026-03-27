# routeapp/kotlin — CLAUDE.md

> Global rules: `/c/web/CLAUDE.md`. Shared domain/API/feature rules: `/c/web/routeapp/CLAUDE.md`. This file covers Kotlin/Compose-specific conventions only.

## Stack
Kotlin, Jetpack Compose, `maplibre-compose`, Room ORM, `supabase-kt`, Ktor HTTP client, `geolocator` (Android Location API), `ActivityResultContracts` for file I/O, `kotlinx.serialization`

## Key Commands
```bash
./gradlew assembleDebug        # debug APK
./gradlew assembleRelease      # release APK
./gradlew bundleRelease        # AAB for Play Store
./gradlew clean                # clear build cache
```
Or use Android Studio → Run button for dev builds with hot reload.

## Folder Structure
```
app/src/main/
  kotlin/com/routeapp/kotlin/
    features/
      map/          # MaplibreMap composable, waypoint markers, route polyline
      routing/      # Valhalla API client, RoutingViewModel
      routes/       # Room DAO, route list composable
      gpx/          # GPX parser + exporter
      elevation/    # Elevation chart composable
      auth/         # Supabase auth
      sync/         # Cloud sync service
    models/
      Waypoint.kt
      RouteModel.kt
      RouteStats.kt
    data/
      AppDatabase.kt     # Room database
      RouteDao.kt
      SettingsDao.kt
    state/
      RouteViewModel.kt      # StateFlow for RouteState
      AuthViewModel.kt
    util/
      Polyline6Decoder.kt    # Valhalla polyline6 decode
      GpxParser.kt
      GpxExporter.kt
  res/
    values/strings.xml
  AndroidManifest.xml
build.gradle.kts
```

## Conventions
- All ViewModel state exposed as `StateFlow<T>` collected via `collectAsState()` in composables
- Room queries are `suspend fun` — always called from a coroutine scope
- No string interpolation in SQL — use Room query parameters
- All reads filter `deletedAt == null` (Room `@Query` with WHERE clause)
- `updatedAt` set by app on every write
- Coroutines: `viewModelScope.launch` for fire-and-forget, `flow {}` for reactive data

## MapLibre Compose
- Package: `dev.sargunv.maplibre-compose:maplibre-compose`
- API is stabilising — check https://github.com/maplibre/maplibre-compose for latest
- Long-press: `onMapLongClick: ((LatLng) -> Boolean)?` parameter on `MaplibreMap`
- See `docs/framework-notes/kotlin.md` for detailed usage

## Android Manifest Permissions
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
Request permissions at runtime using `rememberPermissionState` (Accompanist) or `ActivityResultContracts.RequestPermission`.

## Environment
```kotlin
// local.properties (gitignored)
STADIA_API_KEY=...
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```
Read in `build.gradle.kts`:
```kotlin
val localProps = java.util.Properties().apply { load(rootProject.file("local.properties").inputStream()) }
buildConfigField("String", "STADIA_API_KEY", "\"${localProps["STADIA_API_KEY"]}\"")
```

## Setup Prerequisites
See `docs/setup-android.md` (Android Studio, SDK). No additional tooling needed for Kotlin.

## Docs
- `docs/framework-notes/kotlin.md` — Compose patterns, Room, Ktor, MapLibre-compose
- `docs/architecture.md` — shared domain model
- `docs/api-contract.md` — Valhalla API, GPX format, Supabase schema
