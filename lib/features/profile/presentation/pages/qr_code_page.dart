import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// Encodes the user's phone-based identity into a `crystal://` deep link.
const _qrScheme = 'crystal';
const _qrHost = 'add';

class QrCodePage extends ConsumerWidget {
  const QrCodePage({super.key});

  static String payloadFor({required String uid, required String phone}) =>
      '$_qrScheme://$_qrHost?uid=$uid&phone=${Uri.encodeComponent(phone)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My QR Code')),
      body: const QrCodePanel(),
    );
  }
}

/// The shareable QR panel (own identity) reused by [/qr-hub] and the settings
/// entry point.
class QrCodePanel extends ConsumerWidget {
  const QrCodePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context);
    final profile = ref.watch(ownProfileProvider).valueOrNull;
    final uid = profile?.id ?? '';
    final phone = profile?.phone ?? '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Scan to start a chat',
              style: palette.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your phone number is your identity — no usernames.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CrystalColors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: profile == null || uid.isEmpty
                  ? const SizedBox(
                      width: 240,
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : QrImageView(
                      data: QrCodePage.payloadFor(uid: uid, phone: phone),
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: CrystalColors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: CrystalColors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: CrystalColors.black,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            UserAvatar(profile: profile, radius: 24),
            const SizedBox(height: 8),
            Text(
              profile?.displayName ?? 'You',
              style: palette.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone.isEmpty ? 'No phone yet' : phone,
              style: TextStyle(color: palette.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
