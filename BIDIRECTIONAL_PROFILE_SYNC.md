# Bidirectional Profile Sync: Server + Client Side

## Architecture

Profiles are stored on **both** server and client side with automatic sync:

### Server-Side (`public.profiles`)
- Authoritative source
- Exists at all times
- Never deleted (deletions are soft via `deleted_at` or scope changes)
- Accessed via Supabase RPCs and direct queries

### Client-Side (`localProfiles` Drift table)
- Offline-first cache
- Read/write for instant UI performance
- Syncs to server via `syncProfileToServer()`
- Automatic restore from server if "deleted" locally

## Sync Flow

### 1. Client Updates Profile
```dart
// User edits profile in UI
final updatedProfile = profile.copyWith(displayName: 'New Name');

// Sync to server
await supabasePeopleRepository.syncProfileToServer(updatedProfile);
// - Writes to `public.profiles` table via RPC upsert
// - Also caches locally for offline use
```

### 2. Client "Deletes" Profile Locally
```dart
// User removes profile or goes offline
// No server delete happens - server row stays intact

// Next time app opens or fetches profile:
// - Local cache may be empty/missing
// - Fetch from server AUTOMATICALLY restores the profile
// - Server row is authoritative, so profile "restores"
```

### 3. Fetch Profile (Any Client)
```dart
// First attempt: local cache (instant, offline)
final localProfile = await repo.fetchProfileById(userId);
// If local cache empty/missing:
// Second attempt: Supabase backend (authoritative)
final serverProfile = await repo.fetchProfileById(userId);
// - Server row always exists
// - Local cache gets populated for offline use
// - Profile appears "restored" if it was previously "deleted"
```

## Key Methods

### `syncProfileToServer(UserProfile profile)`
- Upserts profile to `public.profiles` table
- Ensures server has latest client-side changes
- Also caches locally for consistency
- Best-effort (failures don't break local cache)

### `fetchProfileById(String id)`
- Tries local cache first (instant, offline-first)
- Falls back to Supabase backend if cache empty
- Server row is always authoritative
- Profile "restores" from server if previously removed locally

### `deleteProfileLocallyThenRestoreFromServer(String id)`
- Simulates client-side delete by removing from local cache
- Server row remains, so next fetch restores profile automatically
- No explicit server delete needed

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    SERVER-SIDE (public.profiles)                │
│  id, display_name, phone, avatar_url, bio, presence,           │
│  last_seen_at, verification_status, sync_enabled, verified_at   │
│ ───────────────────────────────────────────────────────────────│
│           ▲  syncProfileToServer()                              │
│           │  ──────────────────────────────────────────▶         │
│           │                                        │
│           │  ◀─────────────────────────────────────────  │
│           │  (upsert via RPC)                        │
│           ▼                                        │
│  Server row ALWAYS exists (authoritative)                      │
└───────────────────────────────────────────────────────────────┘
          ▲
          │
          │ fetchProfileById()
          │  (tries local cache first)
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT-SIDE (localProfiles Drift table)     │
│  Same fields as server + device info                         │
│  ──────────────────────────────────────────────────────────────│
│           ▲  cachedProfile()     ▲  upsertProfile()            │
│           │  ─────────────────▶                              │
│           │                                      │
│           │  ◀──────────────────────────────────────────  │
│           │  (read from Drift)                         │
│           ▼                                      │
│  Local cache: instant offline-first, syncs to server          │
└─────────────────────────────────────────────────────────────────┘
```

## Deletion Restoration

**Scenario**: User deletes profile locally on Client A

1. Client A: `deleteProfileLocallyThenRestoreFromServer(id)`
   - Removes from local Drift `localProfiles` table
   - Does NOT delete server row

2. Client A (or Client B) fetches profile:
   - Local cache: empty/missing
   - Server query: `SELECT * FROM profiles WHERE id = ?`
   - **Result**: Server row found → profile RESTORED
   - Local cache populated with server data

3. **Outcome**: Profile appears never deleted from user perspective
   - Server is always authoritative
   - Local cache syncs on every fetch

## Migration Note

No schema changes needed - the `public.profiles` table already exists from
`00030_MASTER_SCHEMA.sql`. The Drift `localProfiles` table also already
exists. This implementation just wires up the sync logic.

## Files Modified

| File | Change |
|------|--------|
| `lib/features/conversations/data/supabase_chat_repositories.dart` | Added `syncProfileToServer()`, `deleteProfileLocallyThenRestoreFromServer()`, updated `_parseProfile()` to include device fields |
| `lib/core/database/local_store.dart` | Already has `upsertProfile()`, `allCachedProfiles()`, `cachedProfile()` - no changes needed |
| `lib/shared/models/user_profile.dart` | Already has all fields including device info - no changes needed |

## Usage Example

```dart
// 1. Fetch profile (local cache first, server fallback)
final profile = await repo.fetchProfileById(userId);

// 2. User edits profile
final updated = profile.copyWith(displayName: 'New Name', bio: 'New bio');

// 3. Sync to server (and cache locally)
await repo.syncProfileToServer(updated);

// 4. Simulate local "delete"
await repo.deleteProfileLocallyThenRestoreFromServer(userId);

// 5. Profile automatically restores on next fetch
final restored = await repo.fetchProfileById(userId);
// restored will have server data, local cache populated
```