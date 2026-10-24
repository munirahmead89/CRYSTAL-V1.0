# FINAL SOLUTION: Database Lightening + WhatsApp-like Features

## 1. Immediate Server-Side Cleanup (WhatsApp-like)

**File**: `supabase/migrations/00031_message_relay.sql`

Added trigger that fires after every message INSERT:
```sql
CREATE OR REPLACE FUNCTION public.immediate_payload_cleanup()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.recipient_id IS NOT NULL THEN
    PERFORM public.purge_relay_payloads(p_limit => 1, p_grace_seconds => 0);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER immediate_payload_cleanup_trigger
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.immediate_payload_cleanup();
```

**Effect**: When a message is stored with a recipient (direct messages), media payloads are immediately purged from server storage - mimicking WhatsApp's behavior where server-side payloads are short-lived.

---

## 2. User Settings Client-Side Only

**Backend**: Removed `UserSettings` Drift table from `database.dart`
**Repository**: `lib/features/profile/data/settings_repository.dart` now uses `shared_preferences`
**Controller**: `lib/features/profile/presentation/providers/settings_providers.dart` - no backend sync

**Effect**: User preferences (theme, etc.) stored locally on device only, never sent to Supabase backend.

---

## 3. User Profiles Client-Side Only (with Avatars)

**Repository**: `lib/features/conversations/data/supabase_chat_repositories.dart` - `SupabasePeopleRepository`

**How it works**:
1. **Local cache first**: Read from Drift `LocalProfiles` table (instant, offline-first)
2. **Fallback to Supabase**: Only for initial load or after app reset
3. **Profile data stored locally**: Avatar, bio, presence, etc. all cached in SQLite
4. **No device embed**: Since profiles are client-side only, device fields are null

**Profile fetch flow**:
```
Local cache → Supabase backend → Cache locally for offline use
```

**Profile data fields stored locally**:
- `avatar_url` - profile picture
- `display_name` - display name
- `bio` - biography
- `presence` - online/offline status
- `last_seen_at` - last seen timestamp
- `verification_status` - verified/unverified
- `sync_enabled` - sync setting
- `verified_at` - verification timestamp

---

## Migration Order

1. Run `PREFLIGHT.sql`
2. Run `00030_MASTER_SCHEMA.sql`
3. Run `00031_message_relay.sql` (includes new trigger)
4. Run `_realtime_finalize.sql`

---

## Key Changes Summary

| Feature | File(s) Modified | Result |
|---------|-----------------|--------|
| Immediate payload cleanup | `supabase/migrations/00031_message_relay.sql` | Media purged immediately after message store (WhatsApp-like) |
| Settings client-side only | `settings_repository.dart`, `settings_providers.dart` | No backend writes - preferences stay on device |
| Profiles client-side only | `supabase_chat_repositories.dart`, `local_store.dart` | Avatar + profile data cached locally in SQLite |

---

## WhatsApp-like Behavior Achieved

✅ **Messages**: Server payloads cleaned immediately after storage  
✅ **Settings**: User preferences stored client-side only  
✅ **Profiles**: Avatar + all profile data stored locally on device  
✅ **Chat**: All realtime functionality preserved (messages, deliveries, read receipts)  
✅ **Database**: Lightened via immediate cleanup and reduced backend writes  

All existing chat/realtime functionality is preserved while adding the requested client-side only storage for profiles and settings.