# Implementation Plan: Crystal Messenger

Building a scalable, offline-first messaging app using Flutter, Supabase, and SQLite (Drift).

## User Review Required

> [!IMPORTANT]
> The implementation follows a strict **Clean Architecture** (Feature-based) and **Offline-First** approach.
> Please ensure you have your **Supabase Project URL and Anon Key** ready for Phase 2.

## Proposed Changes

### Phase 0 — Audit
- [ ] Inspect existing Flutter project.
- [ ] Create `PROJECT_AUDIT.md` mapping current status (DONE/PARTIAL/BROKEN/MISSING).

### Phase 1 — Foundation
- [ ] Update `pubspec.yaml` with core dependencies (Riverpod, GoRouter, Drift, Supabase, etc.).
- [ ] Initialize directory structure (app, core, shared, features).
- [ ] Set up environment configuration (Dev/Prod).
- [ ] Implement global error handling and logging.

### Phase 2 — Supabase & Core Data
- [ ] Configure Supabase client.
- [ ] Set up PostgreSQL schema and Row Level Security (RLS) policies.
- [ ] Initialize Supabase Storage buckets.
- [ ] Implement Edge Functions for server-side logic.

### Phase 3 — SQLite (Offline Cache)
- [ ] Set up Drift (SQLite) database schema.
- [ ] Implement local repositories and caching logic.
- [ ] Build the sync state management.

### Phase 4-15 — Feature Implementation
- **Phase 4**: Auth & Profile (Phone OTP).
- **Phase 5**: Contacts & Discovery.
- **Phase 6-8**: Messaging (1:1, Realtime, Offline Outbox).
- **Phase 9-10**: Media & Voice.
- **Phase 11**: Push Notifications (FCM).
- **Phase 12**: WebRTC Calling.
- **Phase 13-14**: Advanced UI (Reactions, Edit/Delete) & Security Audit.
- **Phase 15**: Production Prep.

## Verification Plan

### Automated Tests
- `flutter test`: Unit and Widget tests for every feature.
- `flutter analyze`: Ensure no linting errors.

### Manual Verification
- Verify Realtime delivery between two device instances.
- Test "Airplane Mode" behavior for SQLite outbox sync.
- Verify RLS policies directly in Supabase SQL editor.
