# Crystal Messenger

WhatsApp-clone built with **Flutter** + **Supabase** + **Erlang** real-time server.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Flutter App    │────▶│    Supabase       │────▶│  PostgreSQL │
│   (Riverpod)     │     │    (Auth, DB,     │     │  (20+ tables│
│                  │     │     Storage,       │     │   RLS, RPCs)│
│                  │     │     Realtime)      │     │             │
└────────┬────────┘     └──────────────────┘     └─────────────┘
         │
         │ WebSocket (triple-fallback)
         ▼
┌──────────────────┐
│  Erlang Server   │
│  (Cowboy WS,     │
│   JWT auth,       │
│   rate limiting,  │
│   offline queue)  │
└──────────────────┘
```

## Features

### Core
- Anonymous auth with phone onboarding
- Real-time 1:1 and group messaging
- Read/delivery receipts (single tick / double tick)
- Typing indicators
- Voice notes, images, video sharing
- Audio/video calls (WebRTC)
- Status updates (24h auto-delete)
- Contact sync (WhatsApp-style auto-add)
- Message reactions
- Message deletion (for everyone / permanently)
- Disappearing messages (24h auto-purge)
- Push notifications (Firebase FCM)
- QR code contact sharing

### Innovations (v2.0)
- **Light/Dark Theme Toggle** - System, Light, or Dark theme with WhatsApp-style light mode
- **Interactive Polls** - Create polls in group chats with anonymous/multi-choice options
- **Smart Replies** - AI-powered contextual reply suggestions (rule-based, no API needed)
- **Scheduled Messages** - Queue messages for future delivery
- **Message Threading** - Reply threads for organized group conversations
- **End-to-End Encryption** - Signal Protocol-inspired E2EE with key bundles and session management
- **Enhanced Attachment Menu** - Unified picker for media, polls, and scheduled messages

## Quick Start

### Prerequisites

- Flutter SDK >= 3.2.0
- Docker Desktop
- Supabase project (hosted or local via `supabase start`)

### Setup (Windows)

```powershell
.\scripts\setup.ps1
```

### Setup (Manual)

```bash
# 1. Environment files
cp .env.example .env                     # Fill in Supabase credentials
cp server/.env.server.example server/.env.server  # Fill in JWT secret

# 2. Flutter dependencies
cd crystal_messenger
flutter pub get

# 3. Start the server
cd ..
docker compose up -d

# 4. Verify
curl http://localhost:8081/health
```

### Run Flutter App

```powershell
cd crystal_messenger

# With environment variables:
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key

# Or with Firebase push notifications:
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-key `
  --dart-define=FIREBASE_PROJECT_ID=your-project `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender `
  --dart-define=FIREBASE_APP_ID=your-app-id
```

### Production Build

```bash
# Android
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# iOS
flutter build ipa --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Project Structure

```
CRYSTAL MESSENGER/
├── crystal_messenger/          # Flutter app
│   ├── lib/
│   │   ├── app/                # MaterialApp, GoRouter
│   │   ├── core/               # Theme, constants, utils
│   │   ├── features/           # Feature modules (auth, chat, calls, etc.)
│   │   ├── services/           # Realtime, push, media, etc.
│   │   ├── database/           # Drift offline DB
│   │   ├── providers/          # Riverpod providers
│   │   └── models/             # Data models
│   └── pubspec.yaml
├── server/                     # Erlang real-time server
│   ├── src/                    # Erlang source
│   ├── Dockerfile
│   └── docker-compose.yml
├── supabase/                   # Supabase config + migrations
│   ├── config.toml
│   ├── functions/              # Edge functions
│   └── migrations/             # SQL migrations (20+ tables)
├── docker-compose.yml          # Full stack orchestration
├── scripts/                    # Setup & deploy scripts
└── .env.example                # Environment template
```

## Database

25+ tables with RLS policies, 20+ RPC functions. See `supabase/migrations/` for the full schema.

Key tables: `profiles`, `chats`, `chat_participants`, `messages`, `message_reads`, `contacts`, `calls`, `statuses`, `message_reactions`, `attachments`, `groups`, `notifications`, `polls`, `poll_options`, `poll_votes`, `scheduled_messages`, `user_key_bundles`

## Deployment

| Component | Deployment | Notes |
|-----------|-----------|-------|
| Supabase | Hosted project | No changes needed |
| Erlang Server | Docker on VPS | `docker compose up -d` |
| Flutter App | App Store / Play Store | Build with `--release` |

## License

Private - Crystal Messenger Team
