import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../models/user_profile.dart';
import 'avatar_source.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    this.profile,
    this.radius = 20,
    this.online,
    this.avatarUserId,
  });

  final UserProfile? profile;
  final double radius;

  /// When non-null, ring the avatar with a thin border: solid green while the
  /// user is online, subtle neutral while offline. `null` renders no ring
  /// (used for group members where presence is not meaningful).
  final bool? online;

  /// The user this avatar belongs to. When it matches the signed-in user, the
  /// presence ring is suppressed entirely — your own avatar never shows a
  /// green/neutral status ring.
  final String? avatarUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (profile?.phone.isNotEmpty == true ? profile!.phone : '?');
    final chars = name.characters;
    final letter = chars.isEmpty ? '?' : chars.first.toUpperCase();

    // Initials are always built, not just used as a fallback: the avatar image
    // resolves asynchronously (signed URL), so there is always a first frame
    // with no image. Previously a broken image left a fully transparent circle,
    // because `onBackgroundImageError` swallowed the error and the CircleAvatar
    // had neither a background colour nor a child.
    final initials = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );

    final path = avatarObjectPath(profile?.avatarUrl);
    final Widget avatar;
    if (path.isEmpty) {
      avatar = initials;
    } else {
      final cacheKey = profile!.avatarUrl!;
      final signed = ref.watch(signedAvatarProvider(path));
      avatar = signed.when(
        loading: () => initials,
        // `signedAvatarProvider` never throws - it resolves failures to null -
        // so the `error:` branch this used to have was unreachable and the
        // cache-first fallback below never ran. A `null` URL now takes the same
        // path, which is what keeps an avatar already in the image cache on
        // screen while offline instead of snapping every contact to initials.
        error: (_, __) => _ImageAvatar(
          url: 'http://offline.local/$path',
          cacheKey: cacheKey,
          initials: initials,
        ),
        data: (url) => url == null || url.isEmpty
            ? _ImageAvatar(
                url: 'http://offline.local/$path',
                cacheKey: cacheKey,
                initials: initials,
              )
            : _ImageAvatar(url: url, cacheKey: cacheKey, initials: initials),
      );
    }

    // Presence ring (WhatsApp-style): a thin solid ring drawn around the
    // avatar instead of a standalone corner dot. Never shown on the current
    // user's own avatar — presence rings only describe other contacts.
    final currentUserId = ref.watch(authStateProvider).user?.id;
    final isSelf = avatarUserId != null && avatarUserId == currentUserId;
    if (online == null || isSelf) return avatar;
    final ringColor = online == true
        ? CrystalColors.green
        : colorScheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
      padding: const EdgeInsets.all(2),
      child: ClipOval(child: avatar),
    );
  }
}

/// Paints the resolved image over the initials.
///
/// The initials stay underneath so a slow or failed load degrades to a
/// recognisable avatar instead of a blank circle, and so there is no layout
/// jump between the placeholder and the loaded image.
class _ImageAvatar extends StatelessWidget {
  const _ImageAvatar({
    required this.url,
    required this.cacheKey,
    required this.initials,
  });

  final String url;
  final String cacheKey;
  final Widget initials;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        initials,
        Positioned.fill(
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              cacheKey: cacheKey,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
