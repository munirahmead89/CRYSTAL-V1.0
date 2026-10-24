# Crystal Messenger

Private messaging for Android with media transfer and offline support.

Flutter client, Supabase backend. The app is end-to-end functional without any
third-party analytics or advertising SDK.

---

## Platform support

| | |
| --- | --- |
| Android | 7.0 (API 24) and later |
| `minSdk` | 24, set by Flutter (`flutter.minSdkVersion`) |
| `targetSdk` / `compileSdk` | 36 |
| Package | `com.munirwaheed.crystal_messenger` |

Android 6.0 is **not** supported. Flutter 3.44 rewrites any literal
`minSdk = 23` in `android/app/build.gradle.kts` back to `flutter.minSdkVersion`
(24) on every build, and that value is an immutable constant. Reaching API 23
would mean pinning an older Flutter toolchain. See the comment in
`build.gradle.kts` before trying.

## Features

- Direct and group chats, with replies, editing, deletion and emoji reactions
- Typing indicators, delivered and read receipts, online status
- Direct device-to-device message delivery between two people who are both online,
  over a WebRTC data channel, with the server still storing every message so
  nothing is lost and history/second-device sync keep working
- Photos, video, voice notes and arbitrary files
- Resumable chunked transfers with SHA-256 verification of both parts and whole
  file, so a received file is provably the file that was sent
- Offline read: a local Drift cache, plus an outbox that queues anything sent
  while disconnected and flushes on reconnect
- Per-contact visibility for phone number, photo and last seen; independent
  toggles for read receipts and typing indicators
- Biometric app lock; in-app account deletion
- Second-device linking by QR code, with linked-device management

## Not present, deliberately

- **No Firebase.** `firebase_core`, `firebase_messaging` and `firebase_crashlytics`
  are gone from `pubspec.yaml`, along with the `com.google.gms.google-services`
  Gradle plugin and every `Firebase.initializeApp()` call. The replacement
  crash reporter (`lib/core/observability/crash_reporter.dart`) writes to a
  size-capped file on the device instead.

  One caveat if you grep the APK: four small
  `com.google.firebase:firebase-{annotations,components,encoders,encoders-json}`
  artifacts still appear in the dependency tree. They are annotation-only jars
  (under 100 KB combined) pulled in transitively by
  `com.google.mlkit:barcode-scanning`, which backs QR scanning. They are not the
  Firebase SDK — there is no `firebase-auth`, `firebase-messaging` or
  `firebase-database` — and they cannot be removed without dropping QR scanning.

- **No end-to-end encryption.** Messages are stored server-side and protected by
  HTTPS, encrypted session storage, private media buckets and row-level security.
  See `store/PRIVACY_POLICY.md`, which states this plainly.
- **No remote push provider.** Notifications are rendered by the app from Supabase
  Realtime, so the app must be running. Waking a killed process would require
  adding a push provider back. Consequently `NotificationService.token()` always
  returns null.
- **No advertising or analytics SDK.**

## Project layout

```
lib/
  app/          router, themes, app shell
  core/         config, database, network, media, sync, security, realtime
  features/     auth, conversations, profile, people, updates, ban
  core/p2p/   peer-to-peer message transport (signaling, ICE, data channel)
  shared/       models, widgets, utilities
supabase/
  functions/    Edge Functions (app-config, presence, send-push, main)
  migrations/   SQL schema and RPCs
deploy/         self-hosted Supabase stack (Docker Compose + Caddy + Kong)
store/          store listing copy, privacy policy, submission guide
tools/          build scripts
test/           137 unit and widget tests
```

State management is Riverpod, written by hand: the project uses **no code
generation** for providers, and `riverpod_generator` is not in use. Only Drift
and Pigeon have generated output (`database.g.dart`, `device_info_api.g.dart`).

## Getting started

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Copy `secrets.env.example` to `secrets.env` and fill in your Supabase URL and
anon key, otherwise the app starts on an explanatory "not configured" screen
rather than crashing.

## Building a release

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_release.ps1
```

This produces a single signed APK in `build/app/outputs/flutter-apk/`
containing `arm64-v8a` and `armeabi-v7a` (~72 MB). Release signing requires
`android/key.properties`; see `tools/key.properties.example` and the signing
section of `store/APKPURE.md`.

**Back up `android/play-upload.jks`.** If it is lost, no future update to this
package name can be published, because Android rejects updates signed by a
different key.

## Backend

Two supported layouts:

1. **Hosted Supabase.** Apply `supabase/migrations/00021_full_schema.sql`, deploy
   the Edge Functions in `supabase/functions/`, then point `SUPABASE_URL` and
   `SUPABASE_ANON_KEY` at the project.
2. **Self-hosted.** `deploy/` contains a Docker Compose stack (Postgres, GoTrue,
   PostgREST, Realtime, Storage, Kong, Caddy with TLS). See
   `deploy/.env.example`.

Note that `deploy/apply.sh` references `deploy/apply.sql`, which does not exist
yet, so the self-hosted path does not currently come up clean.

To keep Supabase credentials out of the binary, set `APP_CONFIG_URL` to an HTTPS
endpoint returning `{"url": ..., "anonKey": ...}`; the app fetches and caches them
in encrypted storage at startup. Without it, both values are compiled into the
APK.

## Peer-to-peer delivery

The direct message path is gated behind `kP2PEnabled` in
`lib/core/p2p/p2p_providers.dart`, currently `false`. While it is off every
message goes through Supabase, which is correct and complete — the P2P path is
an accelerator, not a dependency. See `store/APKPURE.md` section 4.5.

It uses public Google STUN, which covers full-cone and restricted-cone NAT.
Behind symmetric or carrier-grade NAT (most corporate, university and hotel
wifi) no direct channel can form without a TURN relay; supply `TURN_URL`,
`TURN_USERNAME` and `TURN_PASSWORD` at build time. Messages fall back to the
server regardless, so this never costs delivery.

## Testing

```powershell
flutter test
```

Covers the sync engine, outbox queueing, chunked media integrity, transfer
progress, error mapping, call contracts, attachment handling, avatar URL
resolution and the crash reporter.

## Privacy

See `store/PRIVACY_POLICY.md`.