import 'package:crystal_messenger/core/connectivity/connectivity_providers.dart';
import 'package:crystal_messenger/core/network/media_upload.dart';
import 'package:crystal_messenger/core/network/supabase_providers.dart';
import 'package:crystal_messenger/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Upper bound on an avatar upload, in bytes.
///
/// The picker downsamples to 1024px at decode time, so a correctly processed
/// photo is a few hundred KB. This only catches the case where the platform
/// ignored `maxWidth` and handed back the original full-resolution file, which
/// would otherwise be read entirely into memory on a low-memory device.
const int kMaxAvatarBytes = 8 * 1024 * 1024;

/// Sets, replaces or removes the current user's profile picture.
///
/// ## What this fixes
///
/// Uploading worked, but only through two narrow paths — the onboarding screen
/// and one tile in Settings — and with three problems:
///
///  * **Gallery only.** There was no way to take a photo, despite the camera
///    affordance shown on the avatar during onboarding.
///  * **Silence when offline.** The handler began `if (!online) return;`, so
///    tapping the avatar with no connection did nothing at all: no upload, no
///    explanation, no sign the app was even aware of the tap.
///  * **Whole file into memory.** `picked.readAsBytes()` reads the original file
///    before resizing is applied.
///
/// The upload itself (private bucket, per-user path, `upsert`) is unchanged and
/// still correct: an unauthenticated caller cannot read a stranger's picture by
/// guessing their id, because the bucket is private and only signed URLs are
/// ever rendered.
///
/// [context]'s messenger is used for feedback, so the caller must stay mounted
/// across the await; every path checks `mounted` before showing one.
Future<void> editAvatar(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(ownProfileProvider).valueOrNull;
  final hasAvatar = (profile?.avatarUrl ?? '').isNotEmpty;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(sheetContext).pop('camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(sheetContext).pop('gallery'),
          ),
          if (hasAvatar)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Remove photo',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  void say(String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Said out loud rather than returning silently, which is what the old handler
  // did and why the button looked broken with no connection.
  if (!(ref.read(isOnlineProvider).valueOrNull ?? true)) {
    say('You are offline. Connect to change your photo.');
    return;
  }

  try {
    if (action == 'remove') {
      // Clearing the column is enough: `UserAvatar` falls back to initials when
      // the path is empty. The orphaned object is reclaimed by the storage
      // sweeper rather than deleted inline, so a transient failure here can never
      // leave the profile pointing at a file that no longer exists.
      await ref.read(ownProfileProvider.notifier).save(avatarUrl: '');
      say('Photo removed');
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 82,
    );
    if (picked == null) return;

    final size = await picked.length();
    if (size > kMaxAvatarBytes) {
      say(
        'That photo is too large '
        '(${(size / (1024 * 1024)).toStringAsFixed(1)} MB). Pick a smaller one.',
      );
      return;
    }

    final bytes = Uint8List.fromList(await picked.readAsBytes());
    final url = await uploadAvatar(
      client: ref.read(supabaseClientProvider),
      bytes: bytes,
      mimeType: picked.mimeType ?? 'image/jpeg',
    );
    // Saving through ownProfileProvider writes the row and invalidates the
    // cached profile, so every avatar in the app repaints against the new
    // cache-busting path.
    await ref.read(ownProfileProvider.notifier).save(avatarUrl: url);
    say('Photo updated');
  } catch (e) {
    if (kDebugMode) debugPrint('[avatar] $e');
    say('Could not update your photo.');
  }
}
