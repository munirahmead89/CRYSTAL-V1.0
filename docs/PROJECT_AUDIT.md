# Crystal Messenger — Project Audit

Audit date: 2026-10-23

## Scope

This audit covers the Flutter client, Supabase migrations/functions, local persistence, tests, and platform targets currently present in the repository. No production database was contacted and no migration was applied.

## Current implementation

- Flutter application with Riverpod and GoRouter.
- Supabase initialization in `lib/main.dart` with encrypted persisted auth storage.
- Anonymous auth, profile setup, session restoration, and auth-state routing are present.
- Supabase repositories isolate most backend access from presentation code.
- Drift/SQLite local database, outbox queue, background sync, media transfer, and realtime services are present.
- Server-side relay RPCs and RLS migrations exist in `supabase/migrations/00031_full_whatsapp_relay.sql` and `00032_feature_contract.sql`.
- Edge functions exist for app config, presence, push, and a main function.
- Unit and integration tests cover lifecycle, relay, outbox, media, privacy, and migration behavior.
- Android, iOS, macOS, Linux, Windows, and web project targets are present.

## Important findings

### Strengths

1. Supabase tokens are configured for encrypted local persistence rather than plain preferences.
2. Message submission uses a server relay RPC and client idempotency concepts.
3. Offline outbox and synchronization are already implemented and tested in isolation.
4. The repository contains operational scripts and existing release documentation.

### Risks and gaps

1. `SupabaseAuthRepository.signInAnonymously()` falls back to `ClientAuthRepository` after Supabase failure. This can create a local-only identity that cannot participate in server messaging. Phase 3 must distinguish temporary offline restoration from a new backend identity and must never report local-only identity as server-authenticated.
2. The migration named `00031_full_whatsapp_relay.sql` is broad and mixes core schema, media, status, device, and policy concerns. It needs a reviewed baseline and migration inventory before further changes are applied.
3. The profiles read policy currently uses `USING (true)`. This is broader than the product specification and should be replaced with the minimum discovery/profile projection required by supported behavior.
4. The media-chunk policy contains an unconditional access branch (`OR true`) and must be tightened before private media is considered release-ready.
5. The schema has multiple naming generations (`about`/`bio`, `avatar_url`/`avatar_path`, `devices`/`user_devices`). The client currently contains compatibility fallbacks; these should converge through additive, tested migrations.
6. Push notification dependency/configuration is not equivalent to a production push provider. The app currently emphasizes local notifications and has a `send-push` function, but provider credentials and end-to-end delivery verification are not established here.
7. Calling transport is not verified as an implemented WebRTC/provider feature. It must remain explicitly unsupported until transport, signaling, permissions, and device tests exist.
8. No claim is made that migrations, RLS policies, realtime, push, or builds pass against a live Supabase project; this audit is repository-based.

## Phase 1 conclusion

The project is not an empty scaffold. The safe implementation strategy is to preserve the existing client and relay pipeline, create a canonical schema contract, tighten backend authorization incrementally, and add contract/RLS tests before changing user-visible flows.

