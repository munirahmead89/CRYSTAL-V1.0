# API and Realtime Contract

The client uses repository adapters for Supabase access. Direct conversation creation must use the authorized `get_or_create_direct_conversation` workflow. Message sends use the idempotent relay contract with a client-generated message key and must return the authoritative server message.

Realtime subscriptions are bounded to active/relevant conversations. Events are hints to update the local cache; reconnect always performs a cursor-based fetch for missed durable messages. Typing and presence are ephemeral and must not create unbounded database rows.

Errors returned to the client are safe, actionable categories. Server logs must not contain message content, tokens, or private media URLs.

