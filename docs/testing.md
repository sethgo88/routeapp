# Testing

> Framework-specific test commands are in each framework's CLAUDE.md.

## Philosophy

Each framework tests the two most fragile layers:
1. **Domain logic** — polyline6 decoder, GPX parser, sync/upsert logic
2. **Data layer** — SQL queries against real (in-memory) SQLite, not mocks

Do not test the map or UI components in automated tests — they require device rendering.

## Flutter
- `flutter_test` for unit and widget tests
- `flutter drive` or `integration_test` package for on-device integration tests
- Test files live alongside the file under test: `route_notifier_test.dart` next to `route_notifier.dart`

## Tauri
- Vitest + better-sqlite3 for service-layer SQL tests (no Tauri runtime needed)
- `DbAdapter` interface makes services injectable — see betaapp `docs/testing.md` for the full pattern
- `@tauri-apps/plugin-sql` aliased to a stub in `vitest.config.ts`

## Kotlin
- `kotlinx-coroutines-test` + `runTest` for ViewModel and repository unit tests
- `Room.inMemoryDatabaseBuilder` for DAO tests against real SQLite without a device
- Unit tests in `src/test/`; instrumented tests in `src/androidTest/`

## What to test in every framework

| Area | Test |
|---|---|
| Polyline6 decoder | Known encoded string → expected `[lon, lat]` array |
| GPX parser | Valid GPX → correct `Coordinate[]`; missing lat/lon → user-visible error |
| GPX exporter | Route with/without elevation → valid GPX string with correct namespace |
| Route CRUD | Insert, read (deleted_at filter), update, soft delete |
| Sync upsert | Insert then upsert same row → no duplicate; `remote_id` stored |
