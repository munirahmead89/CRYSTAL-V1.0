# Crystal Messenger — Implementation Roadmap

## Status legend

- **Existing:** code is present in the repository.
- **Next:** first implementation work after this audit.
- **Blocked:** requires external configuration or a live test environment.

## Phase 1 — Audit and contracts (completed in repository)

- **Existing:** Flutter, Supabase, Drift, outbox, realtime, media, and tests inventoried.
- **Existing:** current migrations and functions identified.
- **Completed:** `PROJECT_AUDIT.md`, this roadmap, architecture and security contracts.

## Phase 2 — Backend contract hardening (in progress)

1. **Implemented:** added `supabase/migrations/00033_crystal_consolidated_hardening.sql`; it is additive and does not rewrite existing production data.
2. Inventory tables, columns, functions, policies, grants, and realtime publications.
3. **Implemented:** anonymous API profile reads are now denied; authenticated discovery remains temporarily broad pending query consolidation.
4. **Implemented:** removed the unconditional media-chunk access branch and restricted chunks to their uploader.
5. **Implemented:** added conversation/member/message/receipt/reaction policy hardening in the consolidated migration.
6. Add explicit message constraints, sender validation, membership validation, and idempotency coverage where missing.
7. Add SQL policy tests runnable against a disposable Supabase/Postgres environment.
8. **Implemented:** added block-aware, advisory-lock-protected direct conversation creation in the consolidated migration.
9. **Implemented:** added server-owned free/Pro entitlements in the consolidated migration.

## Phase 3 — Anonymous identity correctness (in progress)

1. **Implemented:** configured Supabase auth no longer falls back to a local synthetic identity after anonymous-auth failure.
2. Create a profile through an idempotent server-safe workflow.
3. Keep offline UI/cache access separate from authenticated server identity.
4. Make temporary auth failures retryable and visible; do not silently substitute a local-only user for server auth.
5. Document optional future account linking without adding a login screen.

## Phase 4 — Direct conversations and durable messaging

1. **Implemented:** direct-conversation RPC now validates auth, recipient, self-conversation, blocks, exactly two members, and duplicate safety.
2. Verify exactly two members for direct conversations and enforce block checks.
3. Route all sends through the idempotent relay contract.
4. Reconcile local outbox rows with authoritative server IDs and timestamps.

## Phase 5 — Offline and realtime verification

1. Add schema migrations for local outbox/cursor changes.
2. Verify bounded retry/backoff and restart recovery.
3. Re-fetch missed persisted messages after realtime reconnect.
4. Add deterministic duplicate reconciliation tests.

## Phase 6 — Attachments, receipts, and privacy semantics

Implement private Storage, upload authorization, receipt ownership, delete-for-me, delete-for-everyone, and edit semantics only with backend tests.

## Phase 7 — Push and calling

Push requires a configured provider and device test matrix. Calling requires a real media transport and signaling design. Until then, document both as incomplete rather than shipping a simulated success state.

## Verification gate for every phase

Run `dart format`, `flutter analyze`, targeted tests, and the relevant integration/database tests. Report failures and external blockers explicitly. Never apply migrations to production from this repository without review and backup.

