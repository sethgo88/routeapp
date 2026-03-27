---
paths:
  - "kotlin/app/src/**"
---

## Kotlin Patterns

### ViewModel + StateFlow
- Expose all UI state as `StateFlow<T>` from `ViewModel`.
- Mutable backing field is `private val _state = MutableStateFlow(...)`.
- Public read-only: `val state: StateFlow<T> = _state.asStateFlow()`.
- Collect in composable: `val state by viewModel.state.collectAsState()`.
- Fire-and-forget operations: `viewModelScope.launch { ... }`.
- Reactive streams: use `flow { }` or `callbackFlow { }`.

### Room conventions
- All DAO methods are `suspend fun` (or return `Flow<T>` for reactive queries).
- Always filter soft deletes: `WHERE deleted_at IS NULL` in every `@Query`.
- `updatedAt` is set by the app layer on every write — Room has no trigger mechanism.
- No raw SQL string interpolation — use Room `@Query` parameters (`:paramName`).
- `TypeConverters` handle JSON columns (waypoints, geometry, stats).

### Coroutines
- Use `viewModelScope.launch` in ViewModels. Never create bare `GlobalScope` coroutines.
- Use `withContext(Dispatchers.IO)` for DB and network operations.
- Catch exceptions at the ViewModel layer; update state with an error field rather than
  crashing.
- Use `runTest` + `kotlinx-coroutines-test` for testing suspend functions.

### Naming
- Classes/interfaces: `PascalCase`
- Functions/variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE` in companion objects
- Room column mapping: camelCase field → snake_case via `@ColumnInfo(name = "...")`
