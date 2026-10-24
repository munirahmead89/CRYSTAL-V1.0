# Publishing Crystal Messenger to APKPure

Everything a submission needs: how to build the artifact, what APKPure asks for,
and what is still missing before you can upload.

Current state: **the code is publish-ready; the artwork is not.** See
[Blocking gaps](#blocking-gaps).

---

## 1. Build the APK

From the repository root:

```powershell
tools\build_release.ps1
```

Or directly:

```powershell
flutter build apk --release `
  --target-platform android-arm,android-arm64 `
  --dart-define-from-file=secrets.env
```

Do **not** add `--split-per-abi`. This project configures its own
`ndk.abiFilters` in `android/app/build.gradle.kts`, and Gradle refuses to
configure when `splits.abi` is also present:

```
Conflicting configuration : 'armeabi-v7a,arm64-v8a,x86_64' in ndk abiFilters
cannot be present when splits abi filters are set
```

`--target-platform` is the supported lever: it produces a single
`app-release.apk` holding `arm64-v8a` + `armeabi-v7a`, with the x86 slices
excluded. Pass `-Abi arm64` to build arm64 only:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_release.ps1 -Abi arm64
```

### Current build: arm64 only, 42.4 MB

**This machine cannot currently produce a 32-bit ARM build.** The Dart AOT
compiler for that ABI is blocked at the OS level:

```
Target android_aot_release_android-arm failed: ProcessException:
An Application Control policy has blocked this file
  .../engine/android-arm-release/windows-x64/gen_snapshot.EXE
```

That is Windows Application Control / AppLocker refusing to execute the file —
`gen_snapshot.EXE --help` fails the same way, so it is not specific to this
build. The `android-arm64` and `android-x64` copies of the same binary are not
blocked. This is an environment policy, not a code or project problem, and it is
worth reporting before shipping, because it is exactly the kind of thing that
silently costs you 32-bit devices.

Consequence for the listing: the current APK declares
`native-code: 'arm64-v8a'` and **will not install on 32-bit-only devices**.
Nearly all Android 7.0+ hardware in use is arm64, so this is a small loss, and
it is also why the download is 42.4 MB instead of 71.9 MB. Once the policy
allows `gen_snapshot.EXE` to run, rebuild without `-Abi arm64` to get both.

### Size breakdown

| Library | Size (arm64) | Why it is there |
| --- | --- | --- |
| `libjingle_peerconnection_so.so` | 11.7 MB | WebRTC engine. Still needed: it carries the peer-to-peer message data channel |
| `libflutter.so` | 11.1 MB | Flutter engine |
| `libapp.so` | 9.1 MB | Dart AOT code |
| `libbarhopper_v3.so` | 4.7 MB | ML Kit barcode scanning, for QR codes |
| `libsqlite3.so` | 1.5 MB | `sqlite3_flutter_libs`, for the offline cache |
| `classes.dex` | 6.1 MB | Java/Kotlin bytecode |

Roughly a third of the dual-ABI build is the `armeabi-v7a` copy, which only
32-bit low-end devices need.

### Signing

The release key lives at `android\play-upload.jks`, described by
`android\key.properties`. Neither file is in version control, and both must stay
that way.

**If you ever lose this keystore you can never ship an update to this package
name again.** Anyone who already installed the app will be stuck on that version
forever, because Android refuses updates signed by a different key. Back it up
now, outside the repository, together with the four values in `key.properties`.

To generate a fresh key:

```powershell
keytool -genkey -v -keystore android\play-upload.jks `
  -keyalg RSA -keysize 4096 -validity 10000 -alias upload
```

The build **refuses to produce a release APK** if `key.properties` is missing or
incomplete. That is deliberate: the previous behaviour silently fell back to the
public Android debug key, which installs fine but can never be updated, so it
would have looked like a successful release while being a dead end.

Fingerprints of the current key, needed if you ever register it with a push
provider or a store:

```
SHA1:   42:07:A4:81:41:93:B3:4E:A0:CA:65:F2:6F:73:B5:29:D1:31:5B:6A
SHA256: 20:C3:6F:78:D2:5D:73:27:99:35:3C:D3:82:F7:42:3F:6E:3E:5D:7E:B7:96:B1:2D:0C:B8:94:BA:81:5B:6E:F0
Valid:  24 Sep 2026 -> 9 Feb 2054
```

---

## 2. Android version targets

| Setting | Value | Why |
| --- | --- | --- |
| `minSdk` | 24 | Android 7.0. Set by Flutter, see below |
| `targetSdk` | 36 | Current Play requirement; older targets are flagged |
| `compileSdk` | 36 | Required by `sqflite_android`, which references API 36 symbols |
| `versionCode` | `pubspec.yaml` | Must be **higher** than any version already live |
| `versionName` | `pubspec.yaml` | User-visible, e.g. `1.0.0` |

Advertise **Android 7.0 and later** on the listing. Do not claim Android 6.0
support: Flutter 3.44 rewrites a literal `minSdk = 23` back to
`flutter.minSdkVersion` (24) on every build, so an APK claiming API 23 is not
something this toolchain can produce.

Bump both in `pubspec.yaml` before every upload:

```yaml
version: 1.0.1+2
```

APKPure rejects an upload whose `versionCode` is not greater than the highest it
already serves for your package.

---

## 3. What APKPure requires

### Required, and satisfied

- Signed APK (V1+V2+V3+V4 are all enabled in `android/app/build.gradle.kts`)
- `targetSdk` at the current level
- A reachable privacy policy URL
- Description and category
- Content rating
- No request for excessive permissions beyond the app's function — see the
  justification table in `listing.md`

### Assets you must supply yourself

APKPure displays these prominently. None exist in the repository.

| Asset | Required size | Status |
| --- | --- | --- |
| App icon | 512 × 512 PNG | **Missing.** `android/app/src/main/res/mipmap-*/ic_launcher.png` are still the stock Flutter icons |
| Feature graphic | 1024 × 500 PNG | Missing |
| Phone screenshots | 2–8, portrait, 16:9-ish | Missing. Capture from a device or emulator |
| Tablet screenshots | Optional | Missing |

The current launcher icon is the unmodified Flutter default. It ships, and it
installs, but a listing showing the Flutter logo will not survive contact with
users. Replacing `ic_launcher.png` across the five `mipmap-*` densities with your
own 512 px master is the single highest-impact visual change.

### Fields to copy

The text for all of these is written out in `listing.md` — short description,
full description, release notes, privacy summary, data-safety answers, and the
per-permission justification table. Copy from there rather than writing fresh,
so the claims stay consistent with what the app does.

---

## 4. Blocking gaps

In priority order.

### 4.1 No app icon (blocks a credible listing)

`android/app/src/main/res/mipmap-*/ic_launcher.png` is the stock Flutter icon,
0.4 KB at mdpi. Replace with your own artwork.

### 4.2 No screenshots or feature graphic

Required by the submission form. Capture them from a running build; the screens
worth showing are the chat list, an open conversation with media, an active call,
and the QR device-linking screen.

### 4.3 Privacy policy has no public URL

`store/PRIVACY_POLICY.md` is written and accurate, but APKPure needs a URL a
reviewer can open. Publish it — GitHub Pages is the cheapest option:

```
https://<your-user>.github.io/crystal-messenger/privacy-policy.html
```

Also point the in-app **Settings → Help → Privacy policy** entry at that URL.
It currently renders "Coming soon" (`settings_page.dart`, Help section), which
looks unfinished to a reviewer who is checking.

### 4.4 No version control

This is not a git repository. Before the next release, initialise one and commit
the tree. There are six hand-run `APPLY_*.sql` files at the repository root
(~255 KB) that patch the same schema as
`supabase/migrations/00021_full_schema.sql`; with no history, there is no way to
tell which version of the schema a deployed database is actually on, and no way
to recover if a migration is applied twice.

### 4.5 Peer-to-peer delivery silently stays off

`lib/core/p2p/p2p_providers.dart` sets `kP2PEnabled = false`. Until that is
flipped, messages take the Supabase path only, which is correct and complete —
the direct device-to-device path is an accelerator, not a dependency. Flip it
only after testing it on real devices on both sides of a network change.

With it off, `IceConfig` still reads `TURN_URL`, `TURN_USERNAME`, `TURN_PASSWORD`
and `TURN_URLS`. A build without them falls back to public Google STUN, which
covers full-cone and restricted-cone NAT. Symmetric NAT and carrier-grade NAT —
most corporate, university and hotel wifi — cannot be traversed with STUN alone,
so the direct channel will simply not form there and the message falls back to
the server. That fallback is why this is not a correctness problem, only a lost
optimisation.

Free TURN options: Cloudflare's TURN service (free tier), or your own coturn.

---

## 5. Also worth fixing, not blocking

- `deploy/apply.sh:9` and `deploy/.env.example` reference `deploy/apply.sql`,
  which does not exist. The self-hosted stack will fail on first run.
- `lib/features/profile/presentation/pages/settings_page.dart` still shows
  "Coming soon" on the Account row subtitle even though
  `AccountSettingsPage` and `TwoStepVerificationPage` exist and are routed.
  Harmless, but it undersells the app on its own settings screen.
- `lib/features/updates/presentation/pages/updates_tab.dart` shows
  "Status composer coming soon." The status *viewing* RPCs exist server-side;
  composing statuses does not.
- Unused dev dependencies (`riverpod_generator`, `riverpod_lint`, `custom_lint`,
  `freezed`, `json_serializable`) are declared but never used — the project is
  100% hand-written providers. They slow `pub get` and imply a codegen step that
  does not exist.

---

## 6. After the first upload

- The first review typically takes a few days.
- You will be asked for the privacy policy URL. Have it ready before submitting.
- If a reviewer flags the permission set, the justification table in `listing.md`
  answers each one; `READ_PHONE_STATE` is the only restricted permission and the
  only one without a strong user-visible justification.
- Update the APK by uploading a higher `versionCode`. Same key, always.