# Kotlin + Jetpack Compose Notes

Framework-specific lessons, patterns, and gotchas for the Kotlin implementation.

## Setup (Windows 11)

Only Android Studio is required — no additional tooling. Android Studio bundles:
- Kotlin compiler
- Gradle
- JDK (JBR)
- Android SDK (configured during first-run wizard)

Create new project: Android Studio → New Project → Empty Activity (Compose).

## Key Commands

```bash
# From project root (or use Android Studio Run button)
./gradlew assembleDebug             # debug APK
./gradlew assembleRelease           # release APK (requires signing config)
./gradlew bundleRelease             # AAB for Play Store
./gradlew clean                     # clear build cache
```

Or just hit the green Run button in Android Studio for dev builds.

## MapLibre Compose (`maplibre-compose`)

- GitHub: https://github.com/maplibre/maplibre-compose
- Add to `build.gradle.kts` (app level):
```kotlin
dependencies {
    implementation("dev.sargunv.maplibre-compose:maplibre-compose:<version>")
}
```

- Also add to `settings.gradle.kts` (Maven Central is default):
```kotlin
// If not already present:
repositories { mavenCentral() }
```

**Basic map composable:**
```kotlin
MaplibreMap(
    styleUri = "https://tiles.stadiamaps.com/styles/outdoors.json?api_key=$STADIA_KEY",
    modifier = Modifier.fillMaxSize(),
    onMapLongClick = { latLng -> addWaypoint(latLng) }
)
```

Note: `maplibre-compose` API is still stabilising — check the GitHub for latest composables and parameter names.

## State Management

Use `ViewModel` + `StateFlow` (or `MutableState` for simpler cases):

```kotlin
class RouteViewModel : ViewModel() {
    private val _waypoints = MutableStateFlow<List<Waypoint>>(emptyList())
    val waypoints: StateFlow<List<Waypoint>> = _waypoints.asStateFlow()

    fun addWaypoint(coord: LatLng) {
        _waypoints.update { it + Waypoint(id = UUID.randomUUID().toString(), ...) }
    }
}
```

Collect in composable:
```kotlin
val waypoints by viewModel.waypoints.collectAsState()
```

## HTTP (Valhalla API)

Use `Ktor` (idiomatic Kotlin HTTP client) or `OkHttp`:

```kotlin
// build.gradle.kts
implementation("io.ktor:ktor-client-android:<version>")
implementation("io.ktor:ktor-client-content-negotiation:<version>")
implementation("io.ktor:ktor-serialization-kotlinx-json:<version>")
```

```kotlin
val client = HttpClient(Android) {
    install(ContentNegotiation) { json() }
}
val response: ValhallaResponse = client.post("$VALHALLA_URL/route/v1?api_key=$KEY") {
    contentType(ContentType.Application.Json)
    setBody(routeRequest)
}
```

## SQLite (Room)

```kotlin
// build.gradle.kts
implementation("androidx.room:room-runtime:<version>")
ksp("androidx.room:room-compiler:<version>")
implementation("androidx.room:room-ktx:<version>")
```

Define entity + DAO + database as per Room docs. All queries use coroutines (`suspend fun`).

## GPS

```kotlin
// Manifest permissions (added automatically if using accompanist-permissions)
// ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION

val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
fusedLocationClient.lastLocation.addOnSuccessListener { location ->
    // use location.latitude, location.longitude
}
```

## File I/O (GPX)

```kotlin
// Import: ActivityResultContracts.OpenDocument
val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
    uri?.let {
        val stream = context.contentResolver.openInputStream(it)
        val gpxText = stream?.bufferedReader()?.readText()
        // parse gpxText...
    }
}
launcher.launch(arrayOf("application/gpx+xml", "*/*"))
```

```kotlin
// Export: ActivityResultContracts.CreateDocument
val launcher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/gpx+xml")) { uri ->
    uri?.let {
        context.contentResolver.openOutputStream(it)?.bufferedWriter()?.use { writer ->
            writer.write(gpxString)
        }
    }
}
launcher.launch("route.gpx")
```

## Supabase (`supabase-kt`)

```kotlin
// build.gradle.kts
implementation(platform("io.github.jan-tennert.supabase:bom:<version>"))
implementation("io.github.jan-tennert.supabase:postgrest-kt")
implementation("io.github.jan-tennert.supabase:auth-kt")
```

```kotlin
val supabase = createSupabaseClient(
    supabaseUrl = SUPABASE_URL,
    supabaseKey = SUPABASE_ANON_KEY
) {
    install(Postgrest)
    install(Auth)
}
```

## Gotchas

_Fill in as discovered during implementation._
