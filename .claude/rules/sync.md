---
paths:
  - "*/features/sync/**"
  - "*/features/auth/**"
  - "*/sync/**"
---

## Sync Rules (Local-First)

- **Write SQLite first** — all mutations write to the local SQLite database before any
  Supabase call. The app is always in a consistent state even if sync fails.
- **Upsert to Supabase, never plain insert** — use `ON CONFLICT … DO UPDATE` (or the
  Supabase upsert method) when pushing routes. Plain INSERT will fail on re-sync of
  existing rows.
- **Soft deletes via `deleted_at`** — set `deleted_at` timestamp locally; always filter
  `WHERE deleted_at IS NULL` on every local read. On push, upsert the deleted row so
  Supabase reflects the deletion. Never hard-delete locally before confirming the
  Supabase row is also gone.
- **`remote_id` flow** — new local routes have `remote_id = null`. After a successful
  push upsert, store the returned UUID as `remote_id`. Pull uses `remote_id` to match
  server rows to local rows.
- **Settings key-value sync** — sync `unit_system` (and any future settings) via
  `user_settings` table. Key: setting name. Value: string. Use upsert with
  `ON CONFLICT (user_id, key) DO UPDATE`.
- **All reads filter deleted** — no exceptions. Any query that omits
  `WHERE deleted_at IS NULL` is a bug.
- **Sync trigger** — sync on sign-in and on manual user trigger only. No real-time
  subscription in MVP.
