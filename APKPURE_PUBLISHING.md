# Publishing Crystal Messenger to APKPure

Crystal Messenger is ready to publish. Builds run automatically on GitHub Actions — no local Gradle needed.

## Get the APKs from GitHub Actions

1. Push the project to a GitHub repo (include `.github/workflows/build.yml`).
2. Open **Actions** → **Build Crystal Messenger APKs**. The workflow builds on any push and via **Run workflow** manually.
3. When green, open the finished run and download the **crystal-messenger-apks** artifact:
   - `app-debug.apk` — for testing on a real device
   - `app-release.apk` — the publishable build

## Release signing

The workflow always produces a signed release APK:

- If you set a `KEYSTORE_BASE64` secret, it uses **your keystore** — this is required later for updates (you must keep the same keystore + passwords forever).
- Without the secret it generates a throwaway key per build — fine for a first upload, but you will not be able to upload updates over it.

To set up a permanent key once:

```bash
# 1. Create the keystore locally (JDK included)
keytool -genkeypair -v -storetype JKS -keystore keystore/crystal-release.jks \
  -storepass STRONG_PASS -alias crystal -keypass STRONG_PASS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Crystal Messenger, O=Crystal, C=US"

# 2. In a terminal
certutil -encode keystore/crystal-release.jks keystore/base64.txt   # Windows
# or:  base64 -w0 keystore/crystal-release.jks > keystore/base64.txt  # macOS/Linux

# 3. Copy the contents of keystore/base64.txt into GitHub secret KEYSTORE_BASE64
#    and set KEYSTORE_PASSWORD / KEY_ALIAS(crystal) / KEY_PASSWORD.
```

## Upload to APKPure

1. Go to https://www.apkpure.net/upload (Android developer console).
2. Create a developer account (email verification only).
3. Upload `app-release.apk`.
4. Fill in the store listing:
   - **App name:** Crystal Messenger
   - **Icon / screenshots:** use real screenshots of the app
   - **Tagline:** "Fast, private messenger — no OTP required"
   - **Category:** Communication
5. Submit for review (usually 1–3 days). Use the same signing key for every update.

## Before every update

- Bump `versionCode` and `versionName` in `app/build.gradle.kts`.
- Rebuild via GitHub Actions (same keystore secret).
- Upload the new `app-release.apk` to APKPure as an update.

## APKPure-specific notes

- APKPure allows APKs without Google Play Services dependencies; this app avoids FCM/Play Services entirely, so it is fully compatible.
- The app uses MediaStore/READ_MEDIA_* on Android 13+; `targetSdk = 35` is accepted.
- List the permissions accurately in the store listing (camera, microphone, contacts, location, notifications).