# Database migrations

## Single-file install

For a fresh Supabase project, apply `supabase/migrations/00001_full_whatsapp_backend.sql` once. It is the
ordered combination of the complete backend, including anonymous
identity creation, profiles, conversations, messages, realtime, media chunks,
RLS, retention, and cleanup functions.

## The situation

The schema here was built by hand over time and the SQL is spread across eight
files that overlap. `tools/sql_inventory.ps1` reports **177 distinct objects**
with heavy redefinition between them, and **every `create policy` is a plain
`CREATE`** — so applying any of those files twice aborts the transaction on
`duplicate_object`.

| File | What it is |
| --- | --- |
| `migrations/00021_full_schema.sql` | The canonical base. 6,400 lines, assembled by a PowerShell script that dropped some function bodies along the way |
| `migrations/_realtime_finalize.sql` | Realtime publication + presence RLS. Idempotent, and authoritative for publication membership |
| `migrations/0022_calls_removed_and_message_lifecycle.sql` | Everything added after the base was written |
| `migrations/PREFLIGHT.sql` | Read-only audit. Run this first |
| `../APPLY_THIS_TO_SUPABASE.sql` | An older full copy of the base. Superseded |
| `../APPLY_GAP_FILL.sql` | Targeted fixes. Superseded by 0022 where they overlap |
| `../APPLY_RLS_FIX.sql` | Targeted fixes. Superseded by 0022 where they overlap |
| `../APPLY_AVATAR_FIX.sql`, `../APPLY_AVATAR_PRIVACY.sql` | Avatar policies. Superseded by 0022 section 3 |
| `../APPLY_DELETE_ACCOUNT_RPC.sql` | Already inside 00021 |

**The `APPLY_*.sql` files at the repository root are historical.** They are kept
because a database in the wild was built from them, not because they should be
re-run. `0022` deliberately replaces what they added.

## Apply

```sql
-- 1. Look before you leap. Changes nothing.
\i supabase/migrations/PREFLIGHT.sql

-- Apply the single consolidated backend file.
\i supabase/migrations/00001_full_whatsapp_backend.sql
```

## Why 0022 is safe to re-run

| Object kind | How it is made re-runnable |
| --- | --- |
| Table, column | `create ... if not exists` / `add column if not exists` |
| Function | `create or replace` |
| Policy | preceded by `drop policy if exists`, or wrapped in `exception when duplicate_object then null` |
| Index | `create index if not exists` |
| Drops | `drop ... if exists` / `cascade` |

## After applying

Schedule the disappearing-message sweeper. Without it, the timer can be set in
the app but nothing ever deletes anything:

```sql
create extension if not exists pg_cron;

select cron.schedule(
  'purge-expired-messages',
  '7 * * * *',            -- hourly, at 7 past
  $$select public.purge_expired_messages(500);$$
);
```

`PREFLIGHT.sql` section 7 reports whether this job exists.

## Known limitations

- **Media bytes are not removed by message deletion.** `delete_conversation_messages`
  deletes rows; the uploaded objects in `storage.objects` are referenced only from
  the deleted rows' `media` jsonb, so they become orphans.
  `purge_stale_media_uploads` reaps *abandoned uploads*, not these. A dedicated
  sweeper is still needed if delete-for-everyone is used heavily.
- **Self-hosted projects have no `storage.buckets` table.** 0022 section 3 is
  wrapped in `undefined_table` guards, so it skips cleanly there.
- **No live verification.** These files were reviewed statically - balanced
  `$$` quoting, idempotency guards, and object coverage were checked against the
  Dart call sites - but they have not been executed against a running Postgres.
  `PREFLIGHT.sql` exists so the first real run tells you what state you are in
  before anything changes.

## Things that were broken and are now fixed

Recorded because they explain why the base file looks the way it does:

1. **Six malformed function declarations** (`enable_realtime`, `enable_realtime_scale`,
   `enable_realtime_full` x2, `enable_realtime_calls`) - no parameter list, no
   `RETURNS`, no body, each followed by a `select`. The first is at line 789, so
   a database built from the base file never received anything after it,
   **including the entire chunked-media schema**.
2. **The calls table** outlived the feature and was still published to realtime.
3. **`conversations.disappearing_seconds` did not exist**, though the app has had
   a disappearing-messages setting written to the database and enforced by
   nothing.
