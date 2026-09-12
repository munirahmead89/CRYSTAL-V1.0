# Supabase Setup — Crystal Messenger

Crystal Messenger stores everything in Supabase: Postgres for data, Realtime for live updates, Storage for media, and GoTrue for accounts. This guide walks from zero to a working app.

## 1. Create the project

1. Create a free project at https://supabase.com/dashboard (region near your users).
2. Open your project → **Settings → API**. Copy two values:
   - **Project URL** (e.g. `https://abcdefghijklmno.supabase.co`)
   - **anon / publishable key**
3. Paste them into `gradle.properties` in this repo:

```properties
SUPABASE_URL=https://abcdefghijklmno.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

If you rebuild via GitHub Actions, you can pass them as repo secrets instead of committing them (see step 3).

## 2. Run the schema

Open **SQL Editor → New query**, paste the entire contents of `backend/supabase/schema.sql`, and click **Run**.

This creates:

- Tables: `users`, `conversations`, `conversation_members`, `messages`, `typing`, `statuses`, `status_views`, `calls`, `communities`, `community_members`, `community_announcements`
- Row Level Security policies on every table
- RPC functions: `find_or_create_conversation`, `mark_conversation_read`, `touch_presence`
- Realtime publication for all tables
- A public `media` storage bucket (50 MB limit, images/videos/audio) with policies

## 3. Disable email confirmation (required)

This app signs up with a phone number-derived email and a random password — there is no OTP step.

- Open **Authentication → Providers → Email**.
- Turn **off "Confirm email"**.
- (Optional) Turn **on** "Enable automatic signup confirmation" if your Supabase plan offers it.

## 4. Verify communication works

After installing the app on two devices:

1. Sign up with two different phone numbers.
2. **Chats → New chat** on device A, pick user B.
3. Send a message — it should appear instantly on device B (Realtime), and device B's chat list shows the unread badge + typing indicator when A types.

If messages only appear after reopening the app, check the WebSocket: Realtime V2 requires the anon key in the URL and a valid JWT. Both are handled automatically by `RealtimeClient`.

## 5. GitHub Actions (optional but recommended)

Add these **repository secrets** so CI injects them into `gradle.properties` during builds (they override the committed values):

| Secret | Value |
|--------|-------|
| `SUPABASE_URL` | your project URL |
| `SUPABASE_ANON_KEY` | your anon key |
| `KEYSTORE_BASE64` | `base64` of your release keystore (optional; CI generates one if missing) |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | keystore alias |
| `KEY_PASSWORD` | key password |

## Troubleshooting

- **"Failed to fetch" / empty lists** → check `SUPABASE_URL`/`SUPABASE_ANON_KEY` in BuildConfig and that the schema was run.
- **Signup fails silently** → make sure email confirmation is off and the `users` insert policy exists (schema handles it, but a re-run after re-creating the project is needed).
- **Realtime not working** → confirm `alter publication supabase_realtime add table ...` lines ran; verify in **SQL Editor** that the publication includes `messages`, `conversations`, `typing`.
- **Media upload fails** → the `media` bucket must exist and be public (schema creates it; otherwise create it manually in **Storage → New bucket** → name `media`, public = on).