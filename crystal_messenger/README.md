# Crystal Messenger (Flutter)

A complete WhatsApp-style messaging app built with Flutter, Riverpod, and Supabase.

## Features

- **Real-time messaging** — 1:1 and group chats with optimistic sends, read receipts, typing indicators
- **Audio/Video calls** — WebRTC P2P calling with signaling fallback
- **Voice notes** — Record and share voice messages
- **Media sharing** — Photos, videos, files with signed URL resolution
- **Status updates** — Instagram/WhatsApp-style stories with 24h expiration
- **Contacts sync** — Device contact matching
- **User management** — Anonymous sign-in, phone identity, profile editing
- **Device sync** — Multiple devices via Supabase Realtime
- **Push notifications** — Firebase Cloud Messaging
- **Local drive** — Offline cache with Drift SQLite
- **Scalable** — Clean architecture with feature-first separation
- **Seamless updates** — Play Store in-app updates + feature flags

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.2+ |
| State | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase (Postgres + Auth + Realtime + Storage) |
| Realtime Server | Erlang/OTP WebSocket (same as RN version) |
| Local DB | Drift (SQLite) |
| WebRTC | flutter_webrtc |
| Push | firebase_messaging |
| Media | image_picker, camera, just_audio, record |

## Architecture

```
lib/
├── app/                    # App entry, router
├── core/                   # Theme, constants, utils, errors
├── features/               # Feature-first modules
│   ├── auth/               # Auth, onboarding, permissions
│   ├── chat/               # Messaging
│   ├── contacts/           # Contact management
│   ├── calls/              # Audio/video calls
│   ├── status/             # Stories
│   ├── settings/           # App settings
│   ├── profile/            # User profile
│   ├── qr_code/            # QR identity
│   └── shared/             # Shared widgets
├── services/               # Cross-cutting services
├── database/               # Drift schema
├── models/                 # Data models
└── providers/              # Global providers
```

## Setup

1. **Install Flutter**
   ```bash
   # Download from https://flutter.dev/docs/get-started/install
   flutter --version
   ```

2. **Initialize project**
   ```bash
   cd crystal_messenger
   flutter create . --org com.crystalmessenger
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Generate code (freezed, json_serializable, drift)**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Configure Supabase**
   ```bash
   cp .env.example .env
   # Set SUPABASE_URL and SUPABASE_ANON_KEY
   ```
   Or pass via `--dart-define`:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
   ```

6. **Firebase setup** (for push notifications)
   - Create a Firebase project
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Enable Cloud Messaging

7. **Run**
   ```bash
   flutter run
   ```

## Backend

The Supabase backend (database schema, RPCs, RLS policies) is **identical** to the React Native version. No migration needed. See `supabase/` folder in the RN project for migrations.

The Erlang real-time server is **unchanged** — only the client library differs.

## Building

### Android
```bash
flutter build appbundle --release
flutter build apk --release
```

### iOS
```bash
flutter build ipa --release
```

### CI/CD
Use Codemagic or GitHub Actions with the `flutter` workflow.

## Seamless Updates

Flutter doesn't support Expo-style OTA. Instead:
1. **Play Store in-app updates** — `in_app_update` package
2. **Feature flags** — Supabase config table
3. **Progressive rollout** — 10% → 50% → 100% on Play Store

## License

MIT
