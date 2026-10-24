# Architecture

Crystal Messenger uses a Flutter client with feature modules, repository interfaces, Supabase adapters, and a local Drift cache/outbox.

Presentation code consumes Riverpod providers. Domain interfaces describe auth, profiles, conversations, messaging, receipts, media, realtime, and local persistence. Data adapters implement those interfaces using Supabase or Drift. Infrastructure owns Supabase initialization, secure session storage, background sync, realtime subscriptions, and platform integrations.

The server is authoritative for identity, membership, messages, receipts, blocks, and private media authorization. SQLite is a cache and durable outbox only. Realtime is an acceleration/notification channel; reconnect logic must fetch persisted state.

Supabase-specific calls should remain behind adapters so a subscription upgrade changes deployment/configuration before it changes Flutter code. Replacing Supabase would still require data migration and adapter/configuration work.

## Current flow

`main.dart` → secure runtime config → Supabase initialization → persisted session restoration → Riverpod app → feature repositories → Supabase RPC/table/storage or Drift cache/outbox.

## Non-goals

Ordinary RLS is not end-to-end encryption. A database schema is not a calling transport. Local notification rendering is not remote push delivery.

