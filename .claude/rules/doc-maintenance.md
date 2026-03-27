---
paths:
  - "flutter/lib/**"
  - "tauri/src/**"
  - "kotlin/app/src/**"
  - "docs/**"
---

## Documentation Maintenance Checklist

**After completing any feature or phase**, verify that ALL applicable docs are updated
before closing the task. This is mandatory — not optional.

| Change | Must update |
|---|---|
| Feature added or changed | `docs/features.md` |
| Schema change (SQLite or Supabase) | `docs/architecture.md` |
| API shape change (Valhalla, GPX, Supabase, MapLibre offline) | `docs/api-contract.md` |
| Architecture, navigation, or new screen | `docs/architecture.md` (component tree + relevant section) |
| Framework evaluation note | `docs/evaluation.md` |
| New library, pattern, or gotcha | `docs/framework-notes/<fw>.md` |
| Android setup step | `docs/setup-android.md` |

**How to apply:** Before marking a feature/phase complete, walk through each row above
and confirm whether the change applies. If it does, update the doc. Do not skip
"reference" docs (architecture, api-contract) in favor of only updating "checklist"
docs (evaluation, features).
