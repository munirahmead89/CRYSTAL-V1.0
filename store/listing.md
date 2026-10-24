# Crystal Messenger — store listing copy

Paste-ready fields for an APKPure submission. Every feature named here is
implemented and reachable in the shipped UI. See `APKPURE.md` for the submission
mechanics and required assets.

---

## App name

Crystal Messenger

## Package name

`com.munirwaheed.crystal_messenger`

## Category

Communication / Social

## Tags

Messaging, Chat, Instant Messaging, Offline

## Short description (max ~80 characters)

Private messaging with media sharing, offline sync and file transfer.

## Full description

Crystal Messenger is a fast, lightweight messaging app for Android. It stays out
of your way: chats open instantly, work on a bad connection, and keep working
when the network does not.

**Messaging that keeps up**
- One-to-one and group chats
- Message replies, editing and deletion
- Emoji reactions on individual messages
- Typing indicators, delivered and read receipts
- Online status and last seen, per-contact visibility
- Link previews for shared URLs

**Share anything, reliably**
- Photos, video, voice notes and any file type
- Large files transfer in resumable chunks, so a dropped connection resumes
  instead of restarting
- Every part is verified with a SHA-256 fingerprint, so a received file is
  provably the file that was sent
- Transfer progress per file, with the option to save received media straight to
  your Downloads folder

**Built for bad networks**
- Messages are cached on-device and readable offline
- Anything you send while offline is queued and sent automatically when you
  reconnect
- No "message failed" dead ends

**Your privacy, your call**
- Control who sees your phone number, profile photo and last seen: everyone,
  contacts only, or nobody
- Turn read receipts and typing indicators on or off independently
- Block people
- Decide whether notification previews show message text
- Delete your account and all your data from inside the app
- Biometric app lock to get into the app

**Two devices, one account**
- Show a QR code to add someone quickly
- Scan a QR code to link a second device to your account, and review or sign out
  linked devices at any time

**And the rest**
- Dark and light themes
- Storage and network usage breakdown
- No advertising SDKs, no data sold, no tracking

## What's new in this version

- Rebuilt release pipeline: minified and resource-shrunk release build, signed
  with a dedicated upload key.
- Targeted the current Android API level (36). Supports Android 7.0 and later.
- Direct device-to-device message delivery between two people who are both
  online, with the server still storing every message so nothing is lost.
- Calling removed entirely, along with the Bluetooth, audio-routing and
  foreground-service permissions it needed.
- Removed the unused Firebase dependency, cutting the app size and the number of
  permissions it no longer needs.
- Interrupted file downloads now resume instead of starting over, and abandoned
  partial downloads are cleaned up automatically.
- Per-user storage quota, so one person's large uploads can no longer use up
  everyone's allowance.
- On-device crash reporting, so faults can be diagnosed without a third-party
  analytics SDK.
- Fixes to chat list and message rendering.

## Privacy policy

See `PRIVACY_POLICY.md` in this folder. Publish it at a public HTTPS URL and put
that URL in the store submission — APKPure requires a reachable policy URL, not a
file on disk.

Note for the reviewer: Crystal Messenger is **not** end-to-end encrypted. Messages
are protected by HTTPS in transit, hardware-backed secure storage for the session,
private storage buckets with short-lived signed URLs for media, and row-level
security in the database. The listing deliberately does not claim end-to-end
encryption.

When two people are online at the same time, messages are also delivered
directly between their two devices over a peer-to-peer data channel, in addition
to being stored on the server. That is a second delivery path, not a substitute
for it: every message is still written to the server, which is what makes chat
history and second-device sync work. Data arriving over the peer channel is
verified against the sender's per-message id, so the same message cannot appear
twice.

## Content rating

Expect a rating equivalent to PEGI 12 / ESRB Teen: user-to-user communication and
user-generated content sharing. No violence, gambling, drugs, or adult content
features are present.

## Data safety declaration

Be accurate here; mismatches between this form and observed behaviour are what
trigger rejections.

| Question | Answer |
| --- | --- |
| Does the app collect user data? | Yes |
| Data types | Name, phone number, photos, user-generated content (messages, media), app interactions, device identifiers, crash logs |
| Is it encrypted in transit? | Yes, HTTPS only (cleartext HTTP is disabled in the manifest) |
| Can the user request deletion? | Yes, in-app: Settings → Account → Delete account |
| Is data shared with third parties? | No. No advertising or analytics SDKs |
| Is data used for tracking? | No |

## Permissions justification

APKPure reviews permission usage. Every declared permission, and why it is needed:

| Permission | Why |
| --- | --- |
| `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` | Talking to the message server and detecting offline vs online |
| `RECORD_AUDIO` | Voice notes |
| `CAMERA` | QR code scanning |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` | Keeping large file transfers alive on unstable networks |
| `WAKE_LOCK` | Preventing the CPU sleeping mid-transfer |
| `POST_NOTIFICATIONS`, `VIBRATE` | Message and transfer notifications |
| `USE_BIOMETRIC` | Optional app lock |
| `RECEIVE_BOOT_COMPLETED` | Resuming queued transfers after a reboot |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_MEDIA_VISUAL_USER_SELECTED` | Attaching media you choose to send (Android 13+ split permissions) |
| `READ_EXTERNAL_STORAGE` (max SDK 32) | Same, on Android 12 and below |
| `WRITE_EXTERNAL_STORAGE` (max SDK 28) | Saving to Downloads on Android 9 and below |
| `READ_PHONE_STATE` | Reading your own carrier name and network type for the Storage & network screen |

`READ_PHONE_STATE` is the one restricted permission here. It is used only to
read the device's own carrier/operator label; no identifier is transmitted. If
you would rather avoid declaring a restricted permission on a public listing,
the honest fix is to remove that settings screen — it is the only consumer.

Camera and microphone are declared as **optional** hardware (`required="false"`),
so the app remains installable on devices without them.

### Permissions added by libraries, not by this app

These appear in the merged manifest even though they are absent from
`AndroidManifest.xml`, because the libraries that ship them declare them. They are
listed here so a reviewer is not surprised:

| Permission | Injected by | Why it is there |
| --- | --- | --- |
| `BLUETOOTH` (max SDK 30) | `flutter_webrtc` | Left over from its audio/video support, which this app does not use. It carries the peer-to-peer data channel |
| `MODIFY_AUDIO_SETTINGS` | `flutter_webrtc` | Same |
| `USE_FINGERPRINT` | `local_auth` | Legacy alias of `USE_BIOMETRIC` for the app lock |
| `FOREGROUND_SERVICE_SHORT_SERVICE` | `workmanager` | Short sync/transfer tasks |

None of them enable a feature the app does not have. If a reviewer challenges
`MODIFY_AUDIO_SETTINGS`, the answer is that it is a `flutter_webrtc`
manifest declaration and no code path in this app calls the audio APIs behind it.

The peer-to-peer connection uses the `INTERNET` permission, already listed above.