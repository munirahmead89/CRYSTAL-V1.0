# Solution Summary: Database Lightening + WhatsApp-like Relay Server

## 1. Reduce Unused Tables/Rows

### Periodic Payload Cleanup
```sql
-- Run via cron/scheduler (e.g., hourly)
SELECT * FROM public.purge_relay_payloads(
  p_limit => 500,           -- batch size per run
  p_grace_seconds => 259200 -- 3 days grace period
);
```

### Adjust relay_config Parameters
```sql
UPDATE public.relay_config SET
  cleanup_grace_seconds = 259200,      -- 3 days (adjust based on your needs)
  cleanup_batch_size = 500,            -- rows per cleanup run
  require_all_devices = false,         -- allow cleanup if some devices unacked
  delete_window_seconds = 60;          -- delete-for-everyone window
```

### Leverage Existing Partial Indexes
These already keep queries efficient as tables grow:
- `idx_messages_recipient_relay` - only `retention_state = 'retained'` rows
- `idx_messages_cleanup_scan` - only eligible cleanup rows
- `idx_devices_ack_required` - only active+ack_required devices

### Archive Old Conversations
Move completed conversations to separate schema/table after X months, keeping only recent ones in main tables.

---

## 2. WhatsApp-Like Relay Server with Supabase Realtime

### Server-Side (already complete)
- `send_message` RPC - trusted send path with rate limiting, idempotency
- `acknowledge_messages` RPC - per-device delivery receipts
- `mark_read` RPC - read receipts with privacy gating
- `delete_message` RPC - delete-for-everyone with window enforcement
- `purge_relay_payloads` function - cleanup old payloads
- `relay_config` table - configurable cleanup/rate limits

### Client-Side Realtime Subscriptions

| Channel | Purpose | Key Method |
|---------|---------|-----------|
| `messages:$conversationId` | New/updated messages in conversation | `subscribeToMessages()` |
| `receipts` | Global delivery/read receipts | `subscribeToReceipts()` |
| `deletions` | Tombstone events for offline devices | `subscribeToDeletions()` |
| `messagesFeed` | Global feed for chat list reordering | `subscribeToMessageFeed()` |
| `typing:$conversationId` | Typing indicators | `onTyping()` / `sendTyping()` |
| `profile:$userId` | Presence/avatar/name updates | `subscribeToProfile()` |

### Example Usage (from existing code)

```dart
final _realTime = Ref.read(realtimeServiceProvider);

// Subscribe to new messages in conversation
_realTime.subscribeToMessages(conversationId,
  onInsert: (payload) => _messages.insert(...),
  onUpdate: (payload) => _updateMessageStatus(payload),
);

// Global receipt updates
_realTime.subscribeToReceipts((payload) => _updateReceipts(payload));

// Typing indicator
await _realTime.sendTyping(conversationId, 
  userId: currentUserId, isTyping: isTyping);

// Presence
await _realTime.updatePresence('online');
```

### Verification Checklist

1. **Run migrations** in order:
   - `PREFLIGHT.sql`
   - `00030_MASTER_SCHEMA.sql`
   - `00031_message_relay.sql`
   - `_realtime_finalize.sql`

2. **Confirm realtime publications** in Supabase dashboard:
   - Settings → Realtime → Publicaciones
   - Should show: `messages`, `profiles`, `conversations`, `conversation_members`, `devices`, `statuses`, `status_views`, `groups`, `group_members`, `message_reactions`, `typing`

3. **Test message flow**:
   - Send message → appears instantly via realtime `INSERT`
   - Mark delivered → `acknowledge_messages` RPC + realtime receipt UPDATE
   - Read message → `mark_read` RPC + realtime receipt UPDATE
   - Delete message → `delete_message` RPC + tombstone + realtime UPDATE

4. **Database maintenance**:
   - Schedule `purge_relay_payloads` via cron
   - Monitor `relay_config` parameters
   - Periodically archive old conversations