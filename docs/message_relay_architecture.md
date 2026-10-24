# Phase 1 — Reliable Message Relay: Architecture

Companion documents: `message_relay_audit.md` (what exists), this file (how it
is organised), `message_relay_testing.md` (what was executed).

---

## 1. Principles

1. **SQLite is the source of truth for everything the user sees.** The server
   is a relay and a synchronisation peer, never the render path.
2. **Server timestamps are authoritative** for ordering and retention.
   `client_created_at` is display and diagnostics only; it is never consulted
   for authorization or cleanup.
3. **Realtime is a notification mechanism, not a transport.** Every live event
   is recoverable through a bounded, cursor-based reconciliation pass, so a
   missed event costs latency, never a message.
4. **An acknowledgement is evidence of a committed local transaction**, never
   of a socket, a push, or a Realtime event.
5. **Every client-generated identifier is validated against the authenticated
   principal on the server.** Client-side checks are a UX affordance only.

---

## 2. Module layout

Additive. Existing modules keep their names, responsibilities and public API;
nothing is moved or deleted.

```
lib/
  core/
    database/
      database.dart            Drift tables, schemaVersion 8 -> 10
      local_store.dart         transactional local storage + tombstones
      message_relay_store.dart NEW  relay-specific storage (acks, cursors, tombstones)
    sync/
      outbox_sync.dart         existing durable outbox (unchanged contract)
      sync_service.dart        existing cursor engine (extended with deletion recovery)

  features/
    conversations/             existing feature, additive members only
    delivery/                  NEW — the relay protocol
      domain/
        message_lifecycle.dart   DeliveryState / AckKind / RetentionState enums
        relay_envelope.dart      wire envelope + server row decoding
        deletion_scope.dart      DeleteForMe / DeleteForEveryone
        repositories/
          relay_repository.dart  interface
      data/
        supabase_relay_repository.dart
      services/
        relay_send_service.dart
        delivery_acknowledgement_service.dart
        relay_sync_recovery_service.dart
        relay_retention_policy.dart
    message_deletion/          NEW — tombstone semantics
      services/
        tombstone_service.dart

supabase/migrations/
  00030_MASTER_SCHEMA.sql      unchanged (existing installs)
  00031_message_relay.sql      NEW — strictly additive
```

Why two new features and not a `messages` mega-folder: `delivery` owns the
*forward* path (send → store → ack → sync → cleanup) and `message_deletion`
owns the *retrospective* path (tombstone → purge → resurrect-guard). They share
`local_store` and the SQL migration but have independent lifetimes — deletion
survives removal of the send path — which is exactly how the requirements
scope them.

---

## 3. Interfaces

All abstractions are plain Dart `abstract interface class`. No code generation.

| Interface | Responsibility | Implementation |
| --- | --- | --- |
| `LocalStore` (existing, extended) | durable messages, outbox, cursors | Drift |
| `MessageRelayStore` (new) | tombstones, per-device ack ledger, deletion cursors, account scoping | Drift |
| `RelayRepository` (new) | `sendMessage`, `acknowledgeDelivered`, `markRead`, `syncMessages`, `deleteMessage`, `fetchDeletionsSince` | `SupabaseRelayRepository` |
| `MessagesRepository` (existing, extended) | history read, reactions | `SupabaseMessagesRepository` |
| `OutboxSyncEngine` (existing) | durable retry queue | unchanged contract |
| `SyncService` (existing, extended) | cursor reconciliation | extended with tombstone pass |

---

## 4. Message lifecycle

```
        ┌─────────────── client, SQLite ───────────────┐
 compose │  pending ──outbox──► upload ──► sent ────────│
 retry   │    ▲                   │           │          │
         │    │                   │           ▼          │
         │  failed               │      delivered ◄──ack──┤ recipient
         │    │ (retryable)       │           │          │  (after commit)
         │                      read ◄───────┘          │
         └──────────────────────┼───────────────────────┘
 delete-for-everyone ─────────► deleted  (tombstone, payload nulled)
 cleanup (grace passed) ─────► purged    (row kept, payload nulled, dedupe marker)
```

`DeliveryState` is a closed Dart enum — never a raw string at a call site.
Server-side, per-device detail lives in `message_device_acks`, so
`messages.delivered_at` is a **derived summary**, not the truth.

## 5. Data model

### SQLite (`schemaVersion` 10)

| Table | Purpose |
| --- | --- |
| `local_messages` | +`owner_id`, +`server_id`, indexes on `(owner_id, conversation_id, created_at)`, `(owner_id, deleted)` |
| `outbox_messages` | +`owner_id`, +`next_attempt_at`, index on `(owner_id, id)` |
| `message_tombstones` | `(owner_id, message_id)` PK — stale sync can never resurrect |
| `delivery_ack_ledger` | `(owner_id, message_id, ack_kind)` PK — what *this device* already reported, so an ack is never re-sent and never lost |
| `deletion_cursors` | `(owner_id, conversation_id)` → last tombstone timestamp observed |
| `account_scope_claims` | one-time claim record for pre-`owner_id` rows |

### PostgreSQL (additive)

| Object | Purpose |
| --- | --- |
| `messages.*` additions | `client_message_id`, `text`, `media`, `reply_to_message_id`, `edited_at`, `updated_at`, `schema_version`, `encryption_version`, `ciphertext`, `recipient_id`, `retention_state`, `payload_purged_at`, `cleanup_after`, `deleted_by`, `payload_version` |
| `messages_sender_client_uidx` | `UNIQUE (sender_id, client_message_id)` — the idempotency guarantee |
| `message_device_acks` | `(message_id, device_id, ack_kind)` unique — idempotent device acks |
| `message_tombstones` | deletion events; **no FK to `messages`** so a purged row cannot erase the tombstone |
| `relay_config` | singleton: grace period, batch size, delivery policy, size limit |
| `message_rate_limits` | server-side sliding window, per user and per device |
| `devices.status` / `.revoked_at` / `.ack_required` | revocation + per-device delivery policy |

---

## 6. Relay protocol

### Outgoing

1. Client mints `client_message_id` (UUID v4). It is the outbox primary key and
   is **never** regenerated.
2. Local transaction: `INSERT local_messages(owner, client id, state=pending)`
   + `INSERT outbox_messages(owner, client id)` + `INSERT delivery_ack_ledger
   (read=false)`. Commit.
3. UI renders from the local transaction result.
4. Upload → `send_message(...)` RPC over the anon key with the user's JWT.
5. Server: authenticate → membership → rate limit → size/type validation →
   `INSERT ... ON CONFLICT (sender_id, client_message_id) DO NOTHING`.
6. On conflict the RPC returns the **existing** row with `"duplicate": true`.
   A lost response therefore costs one extra round trip, never a duplicate.
7. Client marks `sent` and records `server_id` **only** from the RPC response.
8. Realtime `INSERT` on `messages` notifies authorized recipients.

### Incoming

1. Realtime `INSERT` (or a bounded reconciliation pass) delivers a row.
2. Client verifies conversation id is one it already caches — a conversation
   not in the local list is fetched by `syncInitial` first, never blind-trusted.
3. Dedupe by `message_id` and by `client_message_id`.
4. **Single transaction**: upsert `local_messages`, apply any tombstones for
   that conversation, advance the message cursor **and** the deletion cursor,
   record `delivery_ack_ledger(delivered=false)`. Commit.
5. `acknowledge_messages(ids, device_id)` is sent **only after** step 4 commits.
6. Server validates the device belongs to the authenticated user and is active,
   then inserts into `message_device_acks ON CONFLICT DO NOTHING`.
7. `messages.delivered_at` is recomputed from the ack rows; Realtime `UPDATE`
   on `messages` tells the sender.

### Offline recovery (on start / reconnect)

1. `outbox.flushNow()` — retry every pending upload with the same ids.
2. `syncService.syncInitial()` — chats, then per-conversation message catch-up.
3. `relaySyncRecovery.fetchDeletionEvents()` — tombstones newer than the local
   deletion cursor; applied before the message catch-up so a tombstone always
   wins over a concurrent message.
4. `deliveryAcknowledgementService.flushPending()` — replay unsent acks.

Each pass is bounded: 50 pages of 100 messages, 200 deletions, 100 acks.

---

## 7. Receipts — two distinct concepts

| | Delivery receipt | Read receipt |
| --- | --- | --- |
| Means | recipient device committed to SQLite | user actually saw it |
| Written by | client, after a committed transaction | client, after the chat screen is showing the message |
| Server record | `message_device_acks.ack_kind='delivered'` | `message_device_acks.ack_kind='read'` |
| Suppressed | never | when the sender has disabled read receipts |
| Trigger | any incoming commit | visible window + policy |

`RemoteStatus` on the sender's side is always **derived** from
(`read_at`, `delivered_at`, local state) — never a single mutable status column.

## 8. Relay retention

**Policy (WhatsApp-like, selected during Phase 1 clarification).** A payload
becomes eligible for cleanup only when **every active, `ack_required` device of
the recipient has a `delivered` ack**, *and* a configurable grace period has
elapsed since the last ack. Undelivered messages are never cleaned by age.

`relay_config` toggles this at the server; a deployment may relax it to
primary-device-only without a code change.

Cleanup (`purge_relay_payloads`) is:
- **idempotent** — sets `retention_state='purged'`, so a second run is a no-op;
- **bounded** — `FOR UPDATE SKIP LOCKED ... LIMIT p_limit`;
- **concurrency-safe** — `SKIP LOCKED` means two overlapping cron ticks cannot
  double-process a row;
- **payload-only** — the row survives as a dedupe/version marker;
- **logged without content** — ids, counts and timings only.

### Documented limitation

A device acknowledgement is evidence of a successful local commit. It is **not**
a guarantee of permanent user-owned storage. If a recipient clears app data
after acknowledging, and the grace period has already elapsed, the server copy
is gone and recovery is impossible. Durability beyond acknowledgement requires
an encrypted client-side backup, which is out of scope here.

---

## 9. Deletion

| Scope | Server | Local | Propagation |
| --- | --- | --- | --- |
| **Delete for Me** | none — it must work offline | tombstone row + conversation purge | never leaves the device; a re-sync cannot restore it |
| **Delete for Everyone** | `delete_message` RPC: membership + ownership + age policy, sets `deleted_at`, nulls the payload, writes a tombstone | tombstone row applied on receipt | Realtime `UPDATE` when online; the deletion cursor on reconnect |

**Resurrect guard.** Two independent barriers: (1) a local
`message_tombstones` row checked on every incoming upsert; (2) the cursor's
monotonic timestamp ordering, so a stale cursor can only ever re-fetch an
already-applied tombstone.

Deleting a payload a second time is a no-op. Deleting while a sync is in flight
is safe: the tombstone is applied inside the same transaction as the message
write, so whichever commits last sees both.

---

## 10. Encryption

**There is no end-to-end encryption today** and this work does not add it. See
`store/PRIVACY_POLICY.md`, which already states this honestly.

What is added is the *ability* to add it without another migration:
`messages.ciphertext`, `messages.encryption_version`, `messages.schema_version`,
and a `RelayEnvelope` that carries an opaque payload. `send_message` already
treats the payload as opaque bytes and never requires plaintext, so an
encryption phase only has to change the two clients.

**Not claimed:** confidentiality from the relay operator, forward secrecy,
post-compromise security, or key-verification UX. None of it is implemented.

---

## 11. Security controls

| Control | Where |
| --- | --- |
| All relay writes behind `SECURITY DEFINER` RPCs, `SET search_path = public` | `00031` |
| `EXECUTE` revoked from `PUBLIC`, granted only to `authenticated` | `00031` |
| Column-scoped RLS: clients cannot write `delivered_at`, `read_at`, `deleted_at`, `sender_id`, `conversation_id` | `00031` replaces `"Messages update"` |
| `anon` cannot read `profiles` | `00031` replaces `"Profiles read"` |
| `media_chunks` restricted to the uploader and conversation members | `00031` replaces the `OR true` predicate |
| Every client-supplied id validated against `auth.uid()` + membership | every RPC |
| Per-user and per-device rate limiting | `relay_rate_limit_ok` |
| Payload size and message-type allowlist | `send_message` |
| No `service_role` in the client; no plaintext in logs or cleanup output | audit verified |

---

## 12. Failure-handling matrix

| Failure | Behaviour |
| --- | --- |
| App killed before upload | Outbox row survives; retried with the same id |
| Upload succeeded, response lost | `ON CONFLICT DO NOTHING` → RPC returns the stored row |
| App killed after upload, before local update | Next reconcile maps `client_message_id` → `server_id` |
| SQLite lock / disk error | Outbox row retained, attempt counted, backoff applied |
| Recipient database failure before ack | Nothing is written, nothing is acked; message re-delivered |
| Ack response lost | Ack ledger still says unsent → replayed; `ON CONFLICT DO NOTHING` makes the replay a no-op |
| Expired session | RPC returns 401; rows stay queued and flush after refresh |
| Concurrent acks | `UNIQUE (message_id, device_id, ack_kind)` |
| Concurrent delete + sync | Tombstone applied in the same transaction as the message write |
| Cleanup run twice | `retention_state` guard |
| Supabase outage | Local DB unaffected; fallback poll and outbox backoff |