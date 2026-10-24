# Testing & Verification — Reliable Message Relay

Everything below was executed on 2026-10-17 on the development machine.
Toolchain: **Flutter 3.44.6 / Dart 3.12.2**, SDK at `C:\flutterSDK\flutter`
(not on `PATH` — every command below was run through the absolute `flutter.bat`).

---

## 1. Commands run, and what they produced

| Command | Result |
| --- | --- |
| `flutter pub get` | OK (transitively via `flutter analyze`) |
| `flutter analyze --no-fatal-infos` | **No issues found!** |
| `flutter test` | **240 pass / 2 fail** |
| `flutter build apk --debug` | **`√ Built build\app\outputs\flutter-apk\app-debug.apk`** (68.6 s) |
| `dart run build_runner build --delete-conflicting-outputs` | Succeeded, 430 outputs — regenerated `database.g.dart` for the v10 schema |
| `dart format lib test` | See §6 — this had an unintended consequence |

### Baseline before any change (for comparison)

| Command | Result |
| --- | --- |
| `flutter analyze --no-fatal-infos` | No issues found |
| `flutter test` | **135 pass / 2 fail** |

So: **105 new tests added, zero pre-existing tests regressed.** The two failures
are byte-for-byte the same two as the baseline.

---

## 2. The two failures — pre-existing, not caused by this work

```
test/app/app_test.dart: onboarding completes saving the profile leaves the form in a completed state
test/app/app_test.dart: onboarding completes a failing profile re-read does not lose the completed save
```

Both fail with a Flutter framework assert:

```
Failed assertion: line 521 pos 12: 'inherited != null'
```

`line 521` is inside the onboarding harness (`_buildApp` → `ProviderScope` over
`CrystalMessengerApp`). The assert comes from an
`InheritedElement._inheritedElements` lookup on a defunct element during the
harness's teardown, in the profile-setup flow. It is unrelated to messaging,
the relay, or any file this work touched, and it reproduces on the untouched
baseline. **Deliberately not fixed** — it is outside the scope of the relay work
and fixing it would be unrelated refactoring.

---

## 3. Tests added

### `test/unit/message_lifecycle_test.dart` — 16 tests

Typed lifecycle vocabulary.

- every `DeliveryState` / `AckKind` / `RetentionState` / `DeletionScope` wire
  value round-trips;
- an unknown, null or empty value falls back instead of throwing;
- a caller-supplied fallback beats the default;
- **delivery and read are distinct enum values** (the invariant that makes
  "marked read on arrival" impossible);
- `RetentionState` unknown values default to `retained`, never to `purged`;
- `RelayMessageType.tryParse` is strict against the server allowlist while
  `parse` degrades an unknown type to text;
- `EncryptionVersion.none` is the default and does **not** claim encryption.

> This suite caught a real inconsistency during authoring: `tryParse` originally
> returned `text` for a null/empty input instead of null, so "is this type
> allowed?" and "what should I show?" were the same question. Fixed.

### `test/unit/relay_envelope_test.dart` — 26 tests

Wire decoding, including every legacy-column mismatch the audit found.

- decodes a complete server row; rejects one missing `id`/`conversation_id`/`sender_id`;
- falls back to the row id when `client_message_id` is absent (a 00030 database);
- reads **both** `reply_to_id` and `reply_to_message_id`;
- reads the legacy `content` column as the payload;
- an unknown message type degrades to text;
- bytea `ciphertext` decodes from hex; odd-length and non-hex values are dropped
  rather than thrown on;
- **a deleted message (null payload + `deleted_at`) parses and renders** — the
  combination delete-for-everyone produces;
- `derivedState` is computed from receipts, with `read` outranking `delivered`
  even when clock skew puts the read timestamp first;
- `parsePage` keeps readable rows and **reports** how many were rejected;
- `RelaySendRequest` omits absent optionals entirely, and never pairs plaintext
  with an `encryption_version` or ciphertext with a `text`.

### `test/unit/local_store_relay_test.dart` — 27 tests

Real SQLite (`NativeDatabase.memory()`), not mocks, because a mocked store
proves nothing about transactions.

**Atomic incoming commit** — stores the message, records the outstanding
delivery ack and advances the cursor as one transaction; an outgoing message is
never owed an ack; a duplicate reports "already present"; acknowledgement can be
disabled for a bulk backfill; **a tombstoned message is dropped, not stored**.

**Acknowledgement ledger** — an unreported ack is replayable and a reported one
is not; `markAcksReported` never fabricates an entry for a message this device
never stored; delivery and read are tracked independently; the reported row is
pruned while the unreported one never is.

**Tombstones** — writing one hides an already-cached message while keeping the
thread's shape; **the deletion cursor only moves forward**; a batch reports only
newly-applied events and replays as a no-op; delete-for-me leaves one tombstone
per message and a later sync cannot restore them; tombstones are account-scoped.

**Account isolation** — one account cannot read another's messages, cannot flush
another's outbox, and cannot see another's whole-table read (which is scoped and
bounded); the first account to sign in adopts the pre-upgrade rows; a second
account starts empty; adoption carries the queued outbox with its owner; an
unscoped store behaves exactly as before.

**Transaction atomicity** — `replaceLocalMessage` re-keys in one transaction
(asserted as "exactly one row before and after", since crash-atomicity is a
property of the `transaction()` wrapper and would need fault injection to assert
directly).

> This suite caught **two real bugs in my own code**:
> 1. `commitIncomingMessage` always returned `true`, so a duplicated Realtime
>    event reported "stored" and would have appended the bubble a second time.
> 2. `_writeTombstone` wrote the deletion cursor *unconditionally* before the
>    monotonic guard ran, so a late-arriving older deletion event moved the
>    watermark backwards.

### `test/integration/relay_lifecycle_test.dart` — 34 tests

The failure-simulation matrix from the requirements, driven end-to-end against a
real SQLite store and a scripted relay.

**Outgoing** — queued message survives a restart; a successful send becomes
`sent`; **offline consumes no attempt and does not mark the message failed**; a
failure keeps the row so the same id is retried; **a lost response is recovered,
not duplicated**; repeated retries never mint a second message; the retry budget
produces a `failed` state that stays retryable; a failing row does not block
later messages.

**Incoming** — committed before acknowledged; **no ack is sent when nothing is
stored** (a Realtime event alone never produces a receipt); an offline device
stores and acknowledges later; a recipient database failure means nothing is
acknowledged; **a lost ack response is replayed safely and lands exactly once
more**; concurrent flushes collapse into one pass; **an unregistered device
acknowledges nothing**; a queued backlog is acknowledged in one batch.

**Duplicate events** — a replayed insert does not duplicate the row.

**Deletion** — delete-for-me works with no network and never contacts the
server; **a stale re-fetch cannot resurrect it** (and does not advance the
cursor); delete-for-everyone requires a connection and says so; a server refusal
is reported honestly and hides nothing locally; an unreachable server is reported
as a local-only removal.

**Offline deletion recovery** — a device offline during deletions learns about
them on reconnect; recovery is cursor-bounded and idempotent; a failure leaves the
cursor where it was so the next pass retries; **deletions applied before a
concurrent message fetch still win**; offline recovery is skipped, not attempted.

**Retention** — **an undelivered message is never eligible because it is old**;
all active devices must acknowledge; the grace period is respected; an
already-purged message is not swept again; server configuration is read
defensively (a nonsense grace period does not become a false guarantee); the
user-facing description states the limitation rather than implying a backup.

### `test/support/` — new test doubles

| File | Purpose |
| --- | --- |
| `fake_relay_repository.dart` | In-memory relay with `sendCalls`, `ackCalls`, `afterPages`, `deletionEvents`, and `failNext(name, error, times: n)` for scripting a single failure |
| `exploding_messages_repository.dart` | Throws on any call, so a test that injects a relay proves the **legacy table-write path was not taken** |
| `noop_relay_store.dart` | Mixin supplying neutral defaults for the new `LocalStore` surface, so the two pre-existing `implements LocalStore` doubles did not each need a dozen copy-pasted no-ops |

---

## 4. Features verified by test

| Feature | Evidence |
| --- | --- |
| Outgoing persisted before upload; survives restart | `relay_lifecycle_test` → *queued locally and survives a restart* |
| Retries reuse the same message id | *repeated retries never mint a second message* |
| Lost-response recovery (no duplicate) | *a lost response is recovered, not duplicated*; *a lost acknowledgement response is replayed safely* |
| Offline queueing consumes no attempt | *offline does not consume an attempt* |
| Retry budget is honest and retryable | *the retry budget produces a failed state that stays retryable* |
| Ingest committed before ack | *stores the message, owes an ack, and advances the cursor together* |
| Ack never claimed without a commit | *no acknowledgement is sent when nothing is stored* |
| Ack is device-scoped and unverifiable claims refused | *an unregistered device acknowledges nothing* |
| Duplicate Realtime events are absorbed | *a duplicate commit reports that the message was already there* |
| Deletions propagate to offline devices | *a device offline during a deletion learns about it on reconnect* |
| Stale sync cannot resurrect a deletion | *a stale re-fetch cannot resurrect a deleted-for-me message*; *deletions applied before a concurrent message fetch still win* |
| Delete-for-me needs no network | *delete for me works with no network and stays deleted* |
| Delete-for-everyone is honest about failure | *a server refusal is reported honestly*; *delete for everyone requires a connection* |
| Undelivered messages are never cleaned by age | *an undelivered message is never eligible because it is old* |
| All-devices delivery policy | *all active devices must acknowledge* |
| Grace period is respected | *the grace period is respected* |
| Account isolation | `local_store_relay_test` → account isolation group (5 tests) |
| Legacy-schema compatibility | *falls back to the row id*, *reads both reply columns*, *reads the legacy content column* |

---

## 5. What is **not** verified, and why

These are honest gaps, not oversights.

### 5.1 The SQL was never executed

**No Postgres is available in this environment** — `docker`, `psql`, `pg_ctl` and
`initdb` are all absent. `00031_message_relay.sql` and
`00032_feature_contract.sql` have therefore **never been run**.

What *was* done, statically, by script:

```
00031_message_relay.sql
  dollar-quote tokens : 88 (even)          balanced
  top-level BEGIN;    : 1
  top-level COMMIT;   : 1
  parens outside $$ bodies : 620 open / 620 close
  GRANT/REVOKE: every named function is declared. OK
  DROP FUNCTION: every target is declared in 00030 or 00031. OK
  CREATE OR REPLACE FUNCTION : 35, CREATE FUNCTION : 4, DROP FUNCTION : 11

00032_feature_contract.sql
  dollar-quote tokens : 34 (even)          balanced
  BEGIN/COMMIT        : 2
  parens outside $$ bodies : 179 open / 179 close
  CREATE POLICY : 12 / DROP POLICY IF EXISTS : 12
```

That catches unbalanced quoting and dangling grants. It does **not** catch a
wrong column name, a bad `ON CONFLICT` target, a Postgres version difference, or
a policy that is syntactically valid but semantically too broad.

**Required manual step:** apply both files to a scratch Supabase project, then:

```sql
\i supabase/migrations/00030_MASTER_SCHEMA.sql
\i supabase/migrations/00031_message_relay.sql
\i supabase/migrations/00032_feature_contract.sql
\i supabase/migrations/_realtime_finalize.sql
\i supabase/migrations/PREFLIGHT.sql   -- must report no missing object
```

### 5.2 RLS and authorization are untested

Every RLS check in this project needs a running PostgREST with a real JWT.
**None of it has been executed.** The policy *wording* was reviewed against the
audit findings; the policy *behaviour* is unproven.

Required before trusting the relay:

```sql
-- As user A, must be denied:
SELECT * FROM messages
 WHERE conversation_id = '<a conversation B belongs to>';
UPDATE messages SET delivered_at = now()      WHERE id = '<any id>';
UPDATE messages SET read_at = now(), deleted_at = now() WHERE id = '<any id>';
UPDATE profiles SET role = 'admin', is_banned = false WHERE id = auth.uid();
SELECT * FROM profiles;                        -- as anon
SELECT * FROM media_chunks;
-- As user B, must be denied:
SELECT public.acknowledge_messages(ARRAY['<A's message id>'], '<B's device id>');
SELECT public.delete_message('<A's message id>', 'everyone');
-- As user A, must be refused:
SELECT public.acknowledge_messages(ARRAY['<B's message id>'], '<A's device id>');
```

### 5.3 Cleanup was never run

`purge_relay_payloads`, `purge_expired_tombstones` and `purge_expired_messages`
are static-only. The client-side mirror of the policy
(`RelayRetentionPolicy`) **is** unit-tested, so the eligibility predicate is
verified — but the SQL implementation of it is not.

After applying, schedule and then verify:

```sql
create extension if not exists pg_cron;
select cron.schedule('purge-relay-payloads', '*/5 * * * *',
                     $$select public.purge_relay_payloads();$$);
select cron.schedule('purge-relay-tombstones', '17 4 * * *',
                     $$select public.purge_expired_tombstones();$$);
select cron.schedule('purge-device-link-sessions', '*/15 * * * *',
                     $$select public.purge_expired_device_link_sessions();$$);
```

Idempotency check: run it twice, confirm the second run reports `purged: 0`, and
confirm an **undelivered** old message is still `retention_state = 'retained'`
afterwards.

### 5.4 No live Supabase, no two devices

There are no Supabase credentials in this environment (`secrets.env` was not
read; only `secrets.env.example` was inspected, for key *names*). The following
therefore **cannot** be claimed:

- end-to-end delivery against a real server;
- `send_message` rate-limit and membership enforcement;
- Realtime insert/update/tombstone delivery against real Postgres;
- multi-device ack behaviour with two registered devices;
- push notification delivery;
- **two physical devices** — the "recipient reconnects after multiple queued
  messages" and "deletion while the recipient is offline" scenarios were
  simulated in-process against SQLite, not over a real network.

### 5.5 Not covered by tests

- Group chat rendering beyond a single peer (the header/avatar fix is wired but
  untested; `get_my_chats` no longer filters to `type = 'direct'`, so groups
  appear, but this is SQL-only).
- The voice-viewer crash fix (`VoicePlayerControllerScope`) — no widget test.
- `background_sync` re-initialisation — needs a device.
- The `VoicePlayerControllerScope` change was reasoned about, not executed.

---

## 6. Unintended consequence, disclosed

While formatting the new files I ran `dart format lib test` over the **whole**
project. Dart 3.12 uses the newer formatter style, so it rewrote **151
pre-existing files** — whitespace and line breaks only, no semantic change, but
it is an unrelated diff and the project was **not a git repository**, so it
cannot be reverted from here.

Consequences, stated plainly:

- `flutter analyze` and `flutter test` were re-run after the reformat and are
  at the same pass/fail counts, so no behaviour changed.
- The reformat exposed **one** lint regression: it collapsed five
  `if (cond)\n statement;` bodies onto one line, tripping
  `curly_braces_in_flow_control_structures` in
  `sub_settings_pages.dart` (×3), `media_viewer.dart` and
  `message_lifecycle.dart`. All five were given brace blocks. `flutter analyze`
  is back to **No issues found!**
- If the original formatting matters, restore it from a backup or by
  re-running the project's original formatter version. To avoid recurrence,
  this repository needs either a `formatter:` block in `analysis_options.yaml`
  or `dart format` limited to changed files.

---

## 7. Recommended manual Supabase configuration

1. **Apply the migrations** in the order in §5.1, inside one session.
2. **Run `PREFLIGHT.sql` afterwards** and confirm no `MISSING` notices for
   `send_message`, `acknowledge_messages`, `fetch_deletions_since`,
   `delete_message`, `edit_message`, `get_messages_after`, `mark_read`,
   `user_settings`, `message_device_acks` or `message_tombstones`.
3. **Schedule the three sweeps** in §5.3.
4. **Deploy the Edge Functions** if push is wanted:
   ```powershell
   supabase functions deploy app-config --no-verify-jwt
   supabase functions deploy presence    --no-verify-jwt
   supabase functions deploy send-push
   supabase secrets set CRYSTAL_SUPABASE_URL=... CRYSTAL_SUPABASE_ANON_KEY=...
   supabase secrets set UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=...
   ```
5. **Tune `relay_config`** if the defaults are wrong for the deployment:
   ```sql
   update relay_config
      set cleanup_grace_seconds = 900,
          require_all_devices   = true,
          per_user_messages_per_minute = 120,
          per_device_messages_per_minute = 60
    where id;
   ```
6. **Rotate the Edge Function secrets** if `send-push` is enabled — it compares
   `Authorization` by string equality, and an unset
   `SUPABASE_SERVICE_ROLE_KEY` makes that check pass for the literal string
   `"Bearer "`. That defect is **outside this change** and is recorded in
   `message_relay_audit.md`; the fix is a `if (!key) return 503` guard.