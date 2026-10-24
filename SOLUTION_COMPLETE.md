# Solution: Immediate Cleanup + Client-Only User Settings

## Changes Implemented

### 1. Immediate Server-Side Payload Cleanup

**File**: `supabase/migrations/00031_message_relay.sql`

Added trigger that fires after every `INSERT` on `public.messages`:
- Immediately purges media payloads when message has `recipient_id` (direct messages)
- Uses `purge_relay_payloads(p_limit => 1, p_grace_seconds => 0)` 
- Mimics WhatsApp's behavior where server-side payloads are short-lived

**Trigger**: `immediate_payload_cleanup_trigger` - runs after every message insert

### 2. User Settings Client-Side Only

**Backend Changes**:
- Removed `UserSettings` Drift table from `database.dart`
- Removed UserSettings methods from `local_store.dart`
- Settings repository now uses `shared_preferences` for local storage only
- No backend writes - settings are device-private

**Dart Changes**:
- `settings_repository.dart`: Uses SharedPreferences, no Supabase calls
- `settings_providers.dart`: Updated for client-only settings flow
- `AppUserSettings` model remains for local preference management

## Migration Order

1. Run `PREFLIGHT.sql`
2. Run `00030_MASTER_SCHEMA.sql`  
3. Run `00031_message_relay.sql` (includes new trigger)
4. Run `_realtime_finalize.sql`

## Verification

- **Cleanup trigger**: After sending a message with recipient, media payload is immediately purged from server storage
- **Settings**: Use app settings page - values stored locally via SharedPreferences, never sent to Supabase
- **Chat functionality**: Fully preserved - realtime messages, deliveries, read receipts all work normally

## Notes

- The cleanup trigger only affects messages with `recipient_id` (direct messages, not group messages without recipient)
- Group messages retain their payloads as before
- User can still use settings UI - changes are stored locally and persist across app restarts
- No database schema version changes needed - the trigger is additive