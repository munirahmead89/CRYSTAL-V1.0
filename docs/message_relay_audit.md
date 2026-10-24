# Phase 0 — Repository Audit: Reliable Message Relay

Audit date: 2026-10-17. Toolchain: Flutter 3.44.6 / Dart 3.12.2 (SDK at
`C:\flutterSDK\flutter`; not on `PATH`, all commands below were invoked via the
absolute `flutter.bat`).

Baseline evidence gathered **before** any change:

| Command | Result |
| --- | --- |
| `flutter analyze --no-fatal-infos` | **No issues found** (22.4 s) |
| `flutter test` | **135 pass / 2 fail** out of 137 |

The 2 failures are **pre-existing** and unrelated to messaging
(`test/app/app_test.dart` → *"onboarding completes saving the profile leaves the
form in a completed state"* and *"…a failing profile re-read does not lose the
completed save"*). Both fail with a Flutter framework assert
`line 521 pos 12: 'inherited != null'` inside the onboarding harness. Not
touched by this work; see `docs/message_relay_testing.md`.

---

## 1. Current project structure

```
lib/
  app/         router (go_router), theme, app shell, providers
  core/        config, database (Drift), network (Dio), media (chunked
               upload/download), sync (outbox + sync engine), security,
               realtime, notifications, background, connectivity,
               errors (fpdart), logging, observability, permissions,
               platform, storage, theme
  features/    auth, ban, calls, conversations, home, profile, updates
  native/      Pigeon device_info bridge
  shared/      models, ui, utils, widgets
supabase/
  migrations/  00030_MASTER_SCHEMA.sql, _realtime_finalize.sql, PREFLIGHT.sql
               (+ 4 stale PowerShell builders that reference a deleted file)
  functions/   main, app-config, presence, send-push
deploy/        self-hosted Supabase Docker Compose stack + Kong/Caddy
test/          137 tests across app/auth/core/features/privacy/shared/sync
```

**The project already has a `core/sync` module** (`outbox_sync.dart`,
`sync_service.dart`) and **a single well-tested local store**
(`core/database/local_store.dart`). Both are reused, not replaced. The
feature-oriented `domain/data/presentation` split exists for
`conversations` and `auth`; `delivery` and `message_deletion` are the two
gaps and are added as new isolated features.

### Drift / SQLite state

`AppDatabase` (`lib/core/database/database.dart`) is at `schemaVersion = 8`
with a correct incremental `onUpgrade` chain (v2 cursors/reactions → v3
statuses → v4 settings → v5 primary-key self-heal → v6 drop `local_calls` → v7
`reply_to_id` → v8 `forwarded`). `beforeOpen` re-runs `Migrator.createAll()`, so
additive tables are safe on any existing install. Tables present:
`local_profiles`, `local_conversations`, `local_messages`, `outbox_messages`,
`message_reactions_outbox`, `device_sync_cursors`, `sync_state`,
`user_settings`, `local_statuses`, `local_status_views`.

**No indexes** are declared on any local table except the implicit primary keys,
despite `conversation_id` + `created_at` being filtered on every query.

**No `db.transaction(...)` anywhere in `lib/core/database/`.** Every write is
a single-statement Drift call. `LocalStore.replaceLocalMessage`
(`local_store.dart:416`) is DELETE-then-upsert and `deleteConversationLocally`
(`local_store.dart:464`) is three sequential DELETEs — both non-atomic.

### Supabase state

`supabase/migrations/` contains exactly three `.sql` files. `00030_MASTER_SCHEMA.sql`
is the only schema definition and is **fully re-runnable** (`CREATE TABLE IF
NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP POLICY IF EXISTS` +
`CREATE POLICY`, `CREATE INDEX IF NOT EXISTS`).

Twelve tables: `profiles`, `devices`, `device_link_sessions`, `conversations`,
`conversation_members`, `messages`, `message_receipts`, `message_reactions`,
`media_uploads`, `media_chunks`, `statuses`, `status_views`.

RLS is enabled on all twelve. Only **six** policies exist, none scoped with
`TO authenticated`.

---

## 2. Feature matrix

Legend: **OK** working · **PART** present but incomplete/incorrect · **MISS** absent ·
**BROKEN** present but non-functional against the checked-in schema ·
**SEC** security defect.

### Messaging core

| # | Feature | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Client-generated stable message UUID, reused on every retry | **OK** | `chat_providers.dart:691,721` `generateUuid()` used as both `id` and `clientMessageId`; `outbox_sync.dart:376-377` rebuilds the draft from `row.id` |
| 2 | Outgoing persisted locally **before** network attempt | **OK** | `chat_providers.dart:743-744` `upsertLocalMessage` → `enqueueOutbox` → `_pump()` |
| 3 | Durable outbox with attempt counting | **OK** | `outbox_sync.dart:181-228`; row deliberately kept after exhaustion (`:213-216`) |
| 4 | Offline does not consume retry budget | **OK** | `outbox_sync.dart:188-190` |
| 5 | Bounded exponential backoff, flushed on reconnect | **OK** | `outbox_sync.dart:96-144`; `chat_providers.dart:80-96` `ref.listen(isOnlineProvider)` → `flushNow()` |
| 6 | Incoming persisted **before** delivery acknowledgement | **PART** | Local write happens at `chat_providers.dart:592`, ack is sent from the 400 ms timer at `:493`. Ordering is right, but the write is not in a transaction with the sync cursor, and there is **no ack durability** — see #14 |
| 7 | Cursor-based incremental sync | **OK** | `sync_service.dart:85-128`, per-conversation key `messages:<id>`, `maxPagesPerSync = 50` guard |
| 8 | Realtime insert/update subscriptions | **OK** | `realtime_service.dart:67-102` filters `conversation_id eq<id>`, insert **and** update |
| 9 | Realtime reconnect with jittered backoff | **PART** | `realtime_service.dart:31-64`. Backoff counter **never resets on success** → a topic that fails once is permanently clamped at the 8 s cap |
| 10 | Realtime `delete` events | **MISS** | `realtime_service.dart` registers no `PostgresChangeEvent.delete` anywhere |
| 11 | Duplicate realtime events must not duplicate rows | **OK** | `local_store.dart:391` `upsertRemoteMessage` is an upsert keyed on the client id; `chat_providers.dart:536-549` `_mergeHistory` dedupes by `clientMessageId` |
| 12 | Server-side idempotency on `client_message_id` | **BROKEN** | `supabase_chat_repositories.dart:149-195` relies on `23505` from `unique (client_message_id, sender_id)`. `00030_MASTER_SCHEMA.sql:98-114` has **no `client_message_id` column and no such constraint** — the recovery path can never fire and a lost-response retry duplicates the message |
| 13 | Per-device delivery acknowledgement | **MISS** | `message_receipts` (`00030:124-131`) is keyed `UNIQUE(message_id, user_id, status)` — per **user**, no `device_id`. `markDelivered(List<String>)` (`chat_repositories.dart:27`) sends bare ids with no actor or device |
| 14 | Acknowledgement is durable and retryable | **MISS** | `chat_providers.dart:493,675-677` are bare `unawaited` calls with no `.catchError`, no queue, no retry. A failed ack is lost forever |
| 15 | Delivery receipt = recipient durably committed locally | **PART** | Recipient selects `!m.outgoing && m.deliveredAt == null` (`chat_providers.dart:487`) — but `LocalStore.markMessagesRead` (`local_store.dart:203-214`) writes `readAt` only, never `deliveredAt`, so the recipient's own `delivered_at` stays NULL and the whole incoming window is re-queued on every reconcile |
| 16 | Read receipt is a separate user-visible state | **PART** | Distinct `RemoteStatus.seen` and `message_bubble.dart:523-524` green dot. But `markChatRead` is called with **no `upToMessageId`** (`chat_providers.dart:675`), so opening a chat marks the entire server-side conversation read |
| 17 | Read receipts respect the privacy toggle | **MISS** | `_scheduleRead` (`chat_providers.dart:653-681`) never consults `userSettings` |
| 18 | Realtime receipt propagation works | **BROKEN** | `subscribeToReceipts` (`realtime_service.dart:107-122`) listens for **UPDATE only**, while `mark_delivered`/`mark_read` **INSERT** on first use → first delivery emits nothing. `_applyReceipt` (`chat_providers.dart:620-621`) then reads `row['delivered_at']`/`row['read_at']`, which `message_receipts` does not define (it has `status`/`timestamp`) → the whole path is a no-op against this schema |
| 19 | Sent / delivered / read render as distinct states | **PART** | `message_bubble.dart:506-532` maps `sent` and `delivered` to the **same orange dot**; only `seen` is green. Colour-only encoding, no `Semantics` label |
| 20 | Failed uploads remain retryable | **OK** | `outbox_sync.dart:213-219` keeps the row; `chat_providers.dart:817-832` `retryFailed()` |
| 21 | Scroll / pagination / ordering intact | **OK** | `chat_page.dart:741-783` reversed `ListView`, `_onScroll` at `:99-107`, `loadOlderMessages` `chat_providers.dart:552-576`. Keyset `before` is `createdAt` (non-unique) — minor duplicate/skip risk at a page boundary |

### Offline recovery

| # | Feature | Status | Evidence |
| --- | --- | --- | --- |
| 22 | Pending outbox recovered on startup | **OK** | `chat_providers.dart:80-96` |
| 23 | Missing messages fetched on reconnect | **OK** | `_reconcileFromServer` `chat_providers.dart:463-509` + 45 s fallback poll `:380-390` |
| 24 | Delivery/read status recovery | **PART** | Depends on the broken realtime receipt path (#18); recovered only by the ≤45 s poll |
| 25 | Deletion events recovered on reconnect | **MISS** | No delete cursor, no tombstone table, no delete-event subscription. Structurally impossible: a `WHERE id > cursor` pull cannot observe a removal |
| 26 | Sync cursor advances only after a successful commit | **PART** | `sync_service.dart:118` writes the cursor after each non-empty page, but each page is committed by N independent single-statement upserts — a mid-page crash advances the cursor past messages that were never stored |
| 27 | Safe resume after app termination | **OK** | Outbox is on disk; `_flushing`/`_retryTimer` are process-local and rebuilt |
| 28 | Background processing | **PART** | `background_sync.dart` registers one 15-minute `Workmanager` task. Built **without** `mediaUpload` and with `isOnline` defaulting to true (`:78-82`), so a queued media message fails in the background isolate and the offline-no-attempt rule is bypassed |

### Deletion

| # | Feature | Status | Evidence |
| --- | --- | --- | --- |
| 29 | Delete for Me is local-only and undoable | **OK** | `chat_overrides.dart:90-101` + `local_store.dart:464-474`, no server contact. Non-atomic (3 DELETEs) and it silently discards queued outbox rows |
| 30 | Delete for Everyone verifies membership server-side | **PART** | `delete_conversation_messages` (`00030:440-461`) checks `is_conversation_member`. It is a **hard `DELETE`** — `deleted_at` is never written |
| 31 | Delete for Everyone is idempotent | **OK** | Deleting an already-deleted row is a no-op returning 0 |
| 32 | Offline devices learn about deletions | **MISS** | Hard DELETE + no delete-event subscription + additive-only sync = the peer keeps the messages **permanently** |
| 33 | Stale sync cannot resurrect a deleted message | **MISS** | `get_messages` filters `deleted_at IS NULL` (`00030:276`) so tombstones are *excluded* rather than delivered; `LocalMessages.deleted` (`database.dart:90`) is written by `local_store.dart:380` but **never set to true anywhere** |
| 34 | Deleted bubble is reachable | **MISS** | `message_bubble.dart:307-312` renders *"This message was deleted"*, but nothing produces a `deleted == true` message — dead UI |
| 35 | Delete a single message | **MISS** | No `delete_message` RPC; the long-press sheet (`message_bubble.dart:395-495`) has no delete action |
| 36 | Attachment lifecycle follows deletion | **MISS** | `cleanup_ephemeral_media_on_delivery` reads `attachment->>'uploadId'` (`00030:211`) but `Attachment.toServerJson` emits `upload_id` (`chat_message.dart:98`), and it targets bucket `chat_media` while the app uses `attachments`. The trigger is a permanent no-op |

### Server / security

| # | Feature | Status | Evidence |
| --- | --- | --- | --- |
| 37 | RLS enabled on all tables | **OK** | `00030:467-478`, all twelve |
| 38 | Clients cannot change delivery/read state directly | **SEC** | `"Messages update"` (`00030:496-499`) is `USING (is_conversation_member(...))` with **no `WITH CHECK` and no column restriction**. Any member can `UPDATE` any column of any row in their conversations — including `delivered_at`, `read_at`, `deleted_at`, `sender_id`, `conversation_id` |
| 39 | `media_chunks` access control | **SEC** | `"Media chunks access"` (`00030:502-507`) predicate is `(u.uploader_id = auth.uid() OR true)` — `OR true` short-circuits to allow **every role** full `FOR ALL` access to every chunk of every upload |
| 40 | `profiles` not readable anonymously | **SEC** | `"Profiles read"` (`00030:481-482`) is `USING (true)` with no `TO` clause → exposes `phone`, `last_seen`, `role`, `is_banned` to `anon` |
| 41 | No self-service privilege escalation | **SEC** | `"Profiles update"` has no column whitelist → any user can set their own `role`, `verified`, `is_banned` |
| 42 | Least-privilege function grants | **SEC** | **Zero** `GRANT`/`REVOKE` in the repo. All ten `SECURITY DEFINER` functions default to `EXECUTE TO PUBLIC`, so `anon` can call them |
| 43 | `SECURITY DEFINER` functions pin `search_path` | **PART** | Nine of ten pin `SET search_path = public`; `cleanup_ephemeral_media_on_delivery` (`00030:201`) omits it |
| 44 | Anonymous access to private messages | **OK** | `"Messages select"` requires membership |
| 45 | Realtime publication is not over-broad | **PART** | `_realtime_finalize.sql` publishes 10 tables including `message_receipts` and `devices`, which are per-user/per-device data |
| 46 | No service-role key in client code | **OK** | `secrets.env.example` carries only URL + anon key; `app-config/index.ts` reads `Deno.env` only; `presence/index.ts` validates the JWT against GoTrue and never uses `service_role` |
| 47 | Edge function auth | **SEC** | `send-push/index.ts` compares `Authorization: Bearer <service_role>` by string equality; if the env var is unset the check degrades to `auth !== "Bearer "`, which `Authorization: Bearer ` satisfies. `deploy/kong.yml` adds no gateway auth |
| 48 | Server-side rate limiting | **MISS** | No rate-limit table or check in any function. `presence/index.ts` has Redis rate limiting but it fails **open** |
| 49 | Server-side message size/type validation | **MISS** | `send` is a raw PostgREST `INSERT` (`supabase_chat_repositories.dart:149`) — PostgREST only enforces the row-size limit |
| 50 | Request timeouts | **OK** | `redis_presence_service.dart:176` 12 s; Dio defaults apply elsewhere |

### Local storage

| # | Feature | Status | Evidence |
| --- | --- | --- | --- |
| 51 | Unique message ids prevent duplicate local rows | **OK** | `LocalMessages.id` PK = `clientMessageId`; `OutboxMessages.clientMessageId` `.unique()` |
| 52 | Large attachments kept out of SQLite | **OK** | `mediaJson` holds coordinates only; bytes live in `outgoing_media/` staging (`outbox_sync.dart:267-271`) |
| 53 | Transactional message writes | **MISS** | No `db.transaction` in `lib/core/database/` |
| 54 | Indexes for conversation / ordering / pending / sync | **MISS** | No index declared on `local_messages`, `outbox_messages`, `device_sync_cursors` |
| 55 | Deletion tombstones stored locally | **MISS** | No tombstone table |
| 56 | Sync cursors / recovery checkpoints | **PART** | `device_sync_cursors` exists but only for messages; `sync_state` (`local_store.dart:685-702`) is implemented with **zero call sites** |
| 57 | DB survives sign-out | **OK** | `auth_controller.dart:203-216` signs out without touching SQLite |
| 58 | **Account isolation between accounts on one device** | **MISS** | No `owner_id` column on any local table; no `userId` parameter on any `LocalStore` method; `databaseProvider` is never invalidated on auth change. **User A's queued messages are flushed from user B's session** (`outbox_sync.dart:374-379` builds the draft with `getMyId()` = B) |
| 59 | No unbounded queries | **PART** | `local_store.dart:500-503` `appLocalMessages()` scans the whole table |
| 60 | Safe migration on existing installs | **OK** | Drift `beforeOpen` + `Migrator.createAll()`; existing tests in `test/core/database/migration_test.dart` |

### RPCs the client calls vs. what exists

| RPC | Called from | Exists in `00030` |
| --- | --- | --- |
| `send_message` | — | **no** (client uses a raw INSERT) |
| `get_messages` | `supabase_chat_repositories.dart:113` | yes (but returns `content`/`attachment`/`reply_to_id`) |
| `get_messages_after` | `:127` | **no** |
| `mark_read` | `:87` | **no** |
| `mark_delivered` | `:96` | **no** |
| `set_reaction` | `:226` | **no** |
| `set_disappearing_messages` | `:32` | **no** |
| `get_or_create_direct_conversation` | `:54` | **no** |
| `create_group_conversation` | `:66` | **no** |
| `delete_conversation_messages` | `:20` | yes (hard DELETE) |
| `purge_relay_payloads` / cleanup job | — | **no** |
| `acknowledge_messages` | — | **no** |

### Column mismatches that break the client

| Client expects | `messages` actually has |
| --- | --- |
| `client_message_id` | *absent* |
| `text` | `content` |
| `media` | `attachment` |
| `reply_to_message_id` | `reply_to_id` |
| `edited_at` | *absent* |
| `reactions` (aggregate) | *absent* |
| `updated_at` | *absent* |

Also: client reads `conversations.disappearing_seconds`, schema has
`disappearing_duration_seconds`; `send-push/index.ts:94` filters
`devices.status`, which does not exist; `PREFLIGHT.sql:134` and
`supabase/README.md:66` schedule `purge_expired_messages(500)`, which does not
exist; the four `migrations/_*.ps1` builders target a `00021_full_schema.sql`
that has been deleted.

---

## 3. Encryption (Phase 9 input)

**There is no end-to-end encryption.** `README.md:58` and
`store/PRIVACY_POLICY.md` state this plainly and honestly. Messages are stored
as plaintext `content` on the server, protected by HTTPS, RLS and private
media buckets. No key material, identity keys, key rotation or device-key
registration exists. `device_link_sessions.public_key` exists but is unused by
the Dart client.

This work therefore does **not** claim E2EE. It adds
`encryption_version`/`ciphertext`/`schema_version` columns and a typed payload
envelope so a documented encryption phase can land later without another
schema migration, and keeps `send_message` operating on an opaque payload.

---

## 4. Scope decision

| In scope | Out of scope (and why) |
| --- | --- |
| Relay core: send, sync, per-device ack, receipts, tombstones, retention, cleanup | Groups (the schema's receipt model is per-user; adding fan-out is a separate change) |
| Additive SQL migration closing every column/RPC gap the client already hits | Rewriting the media/chunked pipeline |
| Security fixes to the RLS policies the relay path depends on | `profiles` column redesign, search/discovery policy |
| SQLite schema additions, indexes, transactions, account isolation | Calls feature, statuses feature, ban feature |
| Status-indicator fidelity in `message_bubble.dart` | Unrelated visual redesign |
| Relay-focused tests | Fixing the two pre-existing onboarding test failures |

---

## 5. Plan of changes (Phase 1 input)

**New files**

- `supabase/migrations/00031_message_relay.sql` — additive columns, backfill,
  `message_device_acks`, `message_tombstones`, device registry columns,
  `message_rate_limits`, the relay RPCs, RLS remediation, realtime membership.
- `docs/message_relay_architecture.md`
- `docs/message_relay_testing.md`
- `lib/features/delivery/**` — typed lifecycle enums, relay envelope,
  `RelaySendService`, `DeliveryAcknowledgementService`,
  `RelaySyncRecoveryService`, `RelayRetentionPolicy`.
- `lib/features/message_deletion/**` — `DeletionScope`, tombstone service.
- `test/unit/**`, `test/integration/**`, `test/regression/**`

**Modified files**

- `lib/core/database/database.dart` — schema v9/v10: `owner_id` on message
  tables, `message_tombstones`, `delivery_acks`, deletion cursor, indexes.
- `lib/core/database/database.g.dart` — regenerated with `build_runner`.
- `lib/core/database/local_store.dart` — transactional writes, tombstones,
  owner scoping, bounded queries, ack ledger.
- `lib/shared/models/chat_message.dart` — typed lifecycle fields.
- `lib/features/conversations/data/supabase_chat_repositories.dart` —
  `send_message` / `acknowledge_messages` / `delete_message` transport.
- `lib/features/conversations/domain/repositories/chat_repositories.dart` —
  additive interface members.
- `lib/features/conversations/presentation/providers/chat_providers.dart` —
  durable ack, read-receipt policy, real delivered bookkeeping.
- `lib/features/conversations/presentation/widgets/message_bubble.dart` —
  distinct sent/delivered/read indicators.
- `lib/features/conversations/presentation/pages/chats_page.dart` —
  delete-for-everyone per message.
- `lib/core/realtime/realtime_service.dart` — receipt `insert` events,
  tombstone events, backoff reset.
- `lib/core/background/background_sync.dart` — media upload + online guard.

---

## 6. Delivery status

Section 5 above is the **plan as written during Phase 1**. For what was actually
built, tested and *not* verified, see `docs/message_relay_testing.md`. The two
migrations shipped are `00031_message_relay.sql` (the relay) and
`00032_feature_contract.sql` (the client/schema mismatches that were keeping
several shipped features dead).

**Neither SQL file has been executed** — no Postgres is available in this
environment. Both are statically validated only. See `message_relay_testing.md`
§5 for the full list of unverified claims and the manual verification steps.