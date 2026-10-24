import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../conversations/presentation/pages/qr_scanner_page.dart';
import '../../../conversations/presentation/providers/chat_providers.dart';
import 'qr_code_page.dart';

/// WhatsApp-style QR hub: a single screen with a two-button toggle that slides
/// between showing *your* code ("My code") and the live camera scanner
/// ("Scan QR") — no separate pages needed to switch.
class QrHubPage extends ConsumerStatefulWidget {
  const QrHubPage({super.key});

  @override
  ConsumerState<QrHubPage> createState() => _QrHubPageState();
}

class _QrHubPageState extends ConsumerState<QrHubPage> {
  bool _scanning = false;

  Future<void> _onScanned(UserProfile peer) async {
    await ref.read(localStoreProvider).upsertProfile(peer);
    ref.read(chatListProvider.notifier).load(silent: true);
    final conversationId = await ref
        .read(conversationsRepositoryProvider)
        .getOrCreateDirectConversation(peerId: peer.id);
    if (!mounted) return;
    context.go('/chat/$conversationId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR code'),
        actions: [
          // Device linking lives here because it is the same gesture - a QR
          // code that another Crystal install acts on.
          IconButton(
            icon: const Icon(Icons.devices_other_outlined),
            tooltip: 'Link a device',
            onPressed: () => context.push('/link-device'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.qr_code_2_outlined),
                  label: Text('My code'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text('Scan QR'),
                ),
              ],
              selected: {_scanning},
              style: ButtonStyle(
                visualDensity: VisualDensity.comfortable,
                backgroundColor: WidgetStatePropertyAll(
                  theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              onSelectionChanged: (selection) =>
                  setState(() => _scanning = selection.first),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _scanning
            ? QrScannerPanel(key: const ValueKey('scan'), onResult: _onScanned)
            : const QrCodePanel(key: ValueKey('code')),
      ),
      backgroundColor: _scanning ? CrystalColors.black : null,
    );
  }
}
