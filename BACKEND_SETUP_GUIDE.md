# Complete Backend Preparation Guide

## Migration Execution Order

### Step 1: Run PREFLIGHT.sql
```bash
supabase db reset
# Or run manually:
supabase db migrate --file supabase/migrations/PREFLIGHT.sql
```

### Step 2: Run 00030_MASTER_SCHEMA.sql
```bash
supabase db migrate --file supabase/migrations/00030_MASTER_SCHEMA.sql
```
This creates the base schema with all tables: profiles, messages, conversations, etc.

### Step 3: Run 00031_message_relay.sql (CRITICAL)
```bash
supabase db migrate --file supabase/migrations/00031_message_relay.sql
```
**This migration includes:**
- ✅ All relay columns on `public.messages` table
- ✅ `message_device_acks` table
- ✅ `message_tombstones` table  
- ✅ `relay_config` table with immediate cleanup settings
- ✅ `message_rate_limits` table
- ✅ **Immediate payload cleanup trigger** (`immediate_payload_cleanup_trigger`)
- ✅ **Relay config initialization** (cleanup_grace_seconds=0, require_all_devices=false)
- ✅ Helper functions (send_message, acknowledge_messages, mark_read, delete_message, etc.)
- ✅ Realtime finalization setup

### Step 4: Run _realtime_finalize.sql
```bash
supabase db migrate --file supabase/migrations/_realtime_finalize.sql
```
 Publishes these tables for Supabase Realtime:
- profiles, messages, conversations, conversation_members, devices, statuses, status_views, groups, group_members, message_reactions, typing, etc.

---

## Relay Configuration Values

After running `00031_message_relay.sql`, the `relay_config` table is initialized with:

```sql
-- Values set by the migration INSERT statement:
SELECT * FROM public.relay_config;
-- id | cleanup_grace_seconds | require_all_devices | delete_window_seconds | ... other columns
-- ---|-----------------------|---------------------|---------------------|-----|
-- true | 0 | false | 60 | 900, 500, 16384, 262144, 30, 60, 900, 120, 60, 600
```

**These values control:**
| Parameter | Value | Effect |
|-----------|-------|--------|
| `cleanup_grace_seconds` | **0** | Immediate payload cleanup (no grace period) |
| `require_all_devices` | **false** | Cleanup can happen even if some devices haven't acked |
| `delete_window_seconds` | **60** | 1-minute window for delete-for-everyone |
| `cleanup_batch_size` | 500 | Rows per cleanup run |
| `tombstone_retention_days` | 30 | How long tombstones are retained |

---

## Database Schema Verification

### Run these queries to verify backend is correctly set up:

#### 1. Check relay_config values
```sql
SELECT * FROM public.relay_config WHERE id = true;
```

#### 2. Check trigger exists
```sql
SELECT trigger_name, event_manipulation, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'immediate_payload_cleanup_trigger';
```

#### 3. Verify immediate_payload_cleanup function
```sql
SELECT prosrc FROM pg_proc WHERE proname = 'immediate_payload_cleanup';
```

#### 4. Verify messages table has recipient_id column
```sql
\d public.messages
-- Check recipient_id column exists
```

#### 5. Check partial indexes for performance
```sql
SELECT indexname, tablename, indexdef 
FROM pg_indexes 
WHERE tablename = 'messages';
```

---

## Drift Database Verification

### Ensure Flutter Drift database is consistent:

#### 1. Check localProfiles table exists
The Drift database (`lib/core/database/database.dart`) should have `LocalProfiles` in the tables list. It's already there from the original schema.

#### 2. Verify schema version
```dart
// In your Flutter app, check:
final db = AppDatabase.instance;
print(db.schemaVersion); // Should be 10
```

#### 3. Run flutter pub get
```bash
flutter pub get
```

#### 2. Generate drift code
```bash
flutter pub run build_runner build
# Or if already generated:
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Flutter Client Updates

### 1. Update People Repository
The `lib/features/conversations/data/supabase_chat_repositories.dart` already has:
- `syncProfileToServer(UserProfile)` - upserts to server
- `deleteProfileLocallyThenRestoreFromServer(String)` - simulates local delete, server retains row
- Updated `_parseProfile` to include device fields from server

### 2. Update Settings Repository
`lib/features/profile/data/settings_repository.dart` uses `shared_preferences` for client-side only storage.

### 3. Update Settings Providers
`lib/features/profile/presentation/providers/settings_providers.dart` - client-side only settings, no backend sync.

---

## Complete Backend + Client Checklist

### ✅ Server-Side (Supabase)
- [x] Migration `00031_message_relay.sql` run
- [x] `relay_config` initialized with `cleanup_grace_seconds=0`
- [x] `immediate_payload_cleanup_trigger` created
- [x] Realtime publications active (`_realtime_finalize.sql` run)
- [x] RPC functions: `send_message`, `acknowledge_messages`, `mark_read`, `delete_message`, `syncProfileToServer` (if custom)

### ✅ Flutter Client
- [x] `lib/core/database/local_store.dart` - has profile cache methods
- [x] `lib/features/conversations/data/supabase_chat_repositories.dart` - has sync/delete methods
- [x] `lib/features/profile/data/settings_repository.dart` - SharedPreferences only
- [x] `lib/features/profile/presentation/providers/settings_providers.dart` - client-side only
- [x] `lib/shared/models/user_profile.dart` - has all fields including device info
- [x] Run `flutter pub get` then `flutter pub run build_runner build`

### ✅ Testing Checklist

#### 1. Test Immediate Cleanup
```dart
// Send message from C1 to C2
await supabaseMessagesRepository.send(draft);

// Check server immediately purges media
// Run manually:
SELECT * FROM public.purge_relay_payloads(p_limit => 1, p_grace_seconds => 0);
// Text/content/media should be NULL, retention_state = 'payload_purged'
```

#### 2. Test C2 Can Still Send/Receive
```dart
// After C1 sends to C2, C2 should be able to:
// - Send messages to C1
// - Receive new messages
// - This works because require_all_devices=false
```

#### 3. Test Profile Sync
```dart
// 1. Fetch profile (local cache first)
final profile = await repo.fetchProfileById(userId);

// 2. Update and sync to server
final updated = profile.copyWith(displayName: 'New Name');
await repo.syncProfileToServer(updated);

// 3. "Delete" locally
await repo.deleteProfileLocallyThenRestoreFromServer(userId);

// 4. Fetch again - should restore from server
final restored = await repo.fetchProfileById(userId);
```

#### 4. Test Settings Client-Side Only
```dart
// 1. Save setting
await repo.save(userId, settings);

// 2. Fetch setting (from local prefs, not server)
final fetched = await repo.fetch(userId);

// 3. Setting persists locally across app restarts
```

---

## Common Issues & Troubleshooting

### Issue 1: Trigger Not Firing
**Cause**: Migration not run in correct order
**Solution**: Ensure migrations run in order: PREFLIGHT → 00030 → 00031 → _realtime_finalize

### Issue 2: Media Not Being Cleaned
**Cause**: `cleanup_grace_seconds` not set to 0
**Solution**: Check `relay_config` table values:
```sql
UPDATE public.relay_config SET cleanup_grace_seconds = 0 WHERE id = true;
```

### Issue 3: C2 Cannot Send After C1 Sends
**Cause**: `require_all_devices = true`
**Solution**: 
```sql
UPDATE public.relay_config SET require_all_devices = false WHERE id = true;
```

### Issue 4: Profile Not Restoring After "Delete"
**Cause**: Local cache not cleared properly
**Solution**: Ensure `deleteProfileLocallyThenRestoreFromServer` is called, then fetch from server

### Issue 5: Settings Syncing Across Devices
**Cause**: Settings repository still using Supabase
**Solution**: Verify `settings_repository.dart` uses `shared_preferences`, not Supabase client

---

## Final Verification Commands

### Run After Setup
```bash
# 1. Verify Supabase CLI is connected
supabase status

# 2. Check database tables
supabase db list-tables

# 3. Verify RPC functions
supabase functions list

# 4. Run Flutter app
flutter run
```

### Expected Results
- Messages send instantly via realtime
- Media payloads purged immediately after send
- C2 can always send/receive regardless of other clients
- Profile data syncs server ↔ client bidirectionally
- Settings stored client-side only (not on backend)
- Database stays light via automatic cleanup