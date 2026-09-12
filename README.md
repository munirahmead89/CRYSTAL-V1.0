# Crystal Messenger

A full-stack, WhatsApp-style messenger for Android — native Kotlin + Jetpack Compose with a Supabase (Postgres + Realtime) backend. No OTP verification: sign up with just your phone number (email is derived from it internally).

## Features

- Onboarding with no verification — pick a name, enter your phone, done
- Real-time 1:1 chats and group chats (messages, read ticks, typing indicator, online presence)
- Media sharing — camera capture, gallery photos, location, voice notes (hold-to-record)
- Status (updates) with auto-advancing viewer
- Communities (group hub) and group creation
- Call log + call UI/signalling (audio/video call screen; real WebRTC media is not wired up yet — signalling + UI only)
- Settings / profile editing
- SQLite (Room) local cache with offline-first reads
- Published on GitHub Actions automatically (debug + release APKs)

## Stack

| Layer    | Tech |
|----------|------|
| UI       | Jetpack Compose + Material 3, Navigation-Compose, Accompanist Permissions, CameraX |
| Local    | Room (SQLite), DataStore |
| Backend  | Supabase — PostgREST REST, GoTrue auth, Phoenix WebSocket Realtime, Storage |
| Network  | Retrofit + OkHttp + Moshi + kotlinx.serialization |
| Build    | Kotlin 2.2.10, AGP 9.2.1, Gradle 9.7.1, KSP, JDK 17 |

The Supabase client is a thin, hand-rolled layer (`core/supabase`) — no heavy SDK, full control over Realtime V2 wire protocol.

## Configuration

Credentials live in `gradle.properties`:

```properties
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

They are compiled into `BuildConfig` (`BuildConfig.SUPABASE_URL`, `BuildConfig.SUPABASE_ANON_KEY`).

## Backend setup

Run `backend/supabase/schema.sql` once in your Supabase project's SQL editor. It creates all tables, row-level security, realtime publication, RPC functions and the public `media` storage bucket. See `SUPABASE_SETUP.md`.

## Building

Locally (JDK 17 + Android SDK):

```bash
gradlew.bat assembleDebug        # Windows
./gradlew assembleDebug          # macOS/Linux
```

or push to GitHub — the `.github/workflows/build.yml` workflow builds both debug and release APKs and uploads them as artifacts. See `APKPURE_PUBLISHING.md`.

## Architecture

```
app/src/main/java/com/crystal_messenger/app/
├─ core/
│  ├─ database/      Room entities + DAOs + CrystalDatabase
│  ├─ network/       Serialization DTOs
│  ├─ repository/    Chat/Contact/Storage repositories (local + remote)
│  ├─ settings/      SessionManager (DataStore)
│  └─ supabase/      SupabaseClient, RealtimeClient, AuthRepository, RealtimeSynchronizer
├─ features/
│  ├─ onboarding/    No-OTP signup / login
│  ├─ home/          Bottom-nav shell (Chats · Status · Communities · Calls)
│  ├─ chats/         Chat list, chat detail, new chat, group create, contacts
│  ├─ status/        Status list + viewer, new status
│  ├─ communities/   Community hub
│  ├─ calls/         Call log, full-screen call UI, incoming call
│  ├─ camera/        CameraX capture→upload→send
│  └─ profile/       Settings + profile editing
├─ services/         CallService (foreground), CallNotifier
└─ di/               Manual DI (AppContainer)
```

## Communication flow

1. Signup → Supabase GoTrue creates a user; a `users` row is upserted.
2. `RealtimeSynchronizer` opens a Realtime V2 WebSocket and subscribes to all tables.
3. Sending a message: inserted into Room instantly (offline-first), POSTed to PostgREST → broadcast to peer via Realtime → peer's Room updated → UI reacts.
4. Typing, online presence, calls and statuses flow the same way.