# Crystal Messenger — Privacy Policy

**Last updated:** 4 October 2026

This policy explains what data Crystal Messenger collects, why it collects it, and
what control you have over it. It applies to the Crystal Messenger mobile app
(package `com.munirwaheed.crystal_messenger`) and to the server that backs it.

---

## 1. Summary

Crystal Messenger is a messaging app. Messages are transmitted over HTTPS and
stored on our servers so they can be delivered, synced and read on your other
devices.

**Crystal Messenger is not end-to-end encrypted.** Message content is stored on
the server in a form our server operator can read, and is protected by
transport encryption (HTTPS) and access control rather than by end-to-end
cryptography. Please do not rely on this app for communications where that
distinction matters.

## 2. Data we collect

### 2.1 Account data

| Data | Why |
| --- | --- |
| Display name | Shown to the people you talk to |
| Phone number | Lets other people find and contact you. Optionally visible only to contacts, or to nobody |
| Profile photo | Shown to the people you talk to |
| Short bio | Shown on your profile |

You can hide your phone number, profile photo and last-seen time individually in
Settings. The defaults are: phone number visible to contacts only; profile photo
and last seen visible to everyone.

### 2.2 Messages and media

Message text, images, video, voice notes and files you send or receive are
stored on the server, along with their timestamps and sender, so they can be
delivered to recipients, synced across your own linked devices, and rendered in
your chat history. Media files are uploaded in chunks and stored in private
buckets that are only reachable through short-lived signed URLs.

Deleting a message marks it deleted for you and removes the content; you can also
delete your entire account, which removes your profile and your messages as
described in section 4.

### 2.3 Device and connection data

- Device model, OS version, app version and a device identifier, so a phone can
  be recognised as one of your own linked devices and distinguished from another
  person's.
- Online/offline presence and last-seen timestamps.
- Notification-delivery tokens, if and only if a push service is configured. The
  version distributed here has no remote push provider configured, so no such
  token is sent.

### 2.4 Direct device-to-device delivery

When you and another person are both using the app at the same time, a message
may also be delivered straight between your two devices over an encrypted
peer-to-peer data channel, in addition to being stored on our servers. This is
an additional delivery route, not a replacement: every message is still written
to the server.

Establishing that direct connection requires the two devices to exchange
connection details (offer, answer and network routing candidates) through our
messaging server. That handshake contains no message content. If a direct
connection cannot be established, a relay service configured by the operator may
carry the traffic; it is not used otherwise.

We do not record whether a direct connection was used.

### 2.5 Diagnostics

If the app crashes, it writes a short on-device report containing the error type,
a stack trace, the app version and the preceding in-app log breadcrumbs, so the
fault can be diagnosed. These reports stay on your device unless you share them.
They never include message text, phone numbers or authentication tokens.

## 3. Where data is stored and who can see it

Data is stored on servers operated by the app's operator. Your messages are
visible to the operator of those servers, and to the recipients you send them to.
We do not sell your personal data, and we do not share it with advertising or
analytics networks. There is no third-party advertising SDK in this app.

## 4. Your rights and controls

- **Delete your account.** Settings → Account → Delete account permanently
  removes your account, profile, messages, media, contacts and linked devices.
- **Unlink a device.** A device you have linked to your account can be signed out
  and removed from within the app.
- **Hide personal fields.** Phone number, profile photo and last-seen visibility
  can each be set to everyone, contacts only, or nobody.
- **Disable read receipts and typing indicators.**
- **Mute or delete individual chats** at any time.

To request a copy of your data, or to have it corrected or erased where the
in-app controls do not cover it, contact the operator using the details in the
app's "Contact us" settings page.

## 5. Children

Crystal Messenger is not directed at children under 13, and we do not knowingly
collect data from them. If you believe a child has created an account, contact
us so we can delete it.

## 6. Security

- All network traffic is HTTPS. The app refuses plaintext HTTP connections.
- Supabase credentials are not compiled into the app binary; they are fetched at
  runtime over an encrypted channel where configured.
- The session is held in the device's hardware-backed secure storage
  (`EncryptedSharedPreferences`/KeyStore), not in plain shared preferences.
- Profile photos are stored in a private storage bucket and served only through
  short-lived signed URLs, so they cannot be read by guessing a URL.
- Private keys and signing credentials are kept out of version control.

## 7. Changes to this policy

If this policy changes materially, the updated version will be published at the
same location and the "Last updated" date above will change.

## 8. Contact

Privacy questions: use the "Contact us" page inside the app's settings.