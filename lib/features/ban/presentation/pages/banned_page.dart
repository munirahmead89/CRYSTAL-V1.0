import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../ban_providers.dart';

/// WhatsApp-style "your account has been banned" screen.
///
/// Showed in place of the chat shell when the server reports a ban. The user
/// is not allowed to use the app and is offered a single appeal form, exactly
/// like WhatsApp's suspension + appeal flow.
class BannedPage extends ConsumerStatefulWidget {
  const BannedPage({super.key});

  @override
  ConsumerState<BannedPage> createState() => _BannedPageState();
}

class _BannedPageState extends ConsumerState<BannedPage> {
  bool _submitting = false;

  Future<void> _openAppeal() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _AppealDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref.read(submitBanAppealProvider)(reason);
      if (!mounted) return;
      await ref.read(banStatusProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Appeal submitted. We will review it shortly.'),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not submit the appeal.')),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOut() async {
    final auth = ref.read(authRepositoryProvider);
    await auth.signOut();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(banStatusProvider).valueOrNull ?? BanStatus();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CrystalColors.greenDark,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.gpp_bad_outlined,
                      size: 48,
                      color: CrystalColors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your account has been banned',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status.reason?.isNotEmpty == true
                        ? status.reason!
                        : 'This account violated the Terms of Service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: schemeOnSurfaceVariant(theme)),
                  ),
                  if (status.bannedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Banned on ${_formatDate(status.bannedAt!)}.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _openAppeal,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gavel),
                      label: const Text('Request a review'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Switch account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color schemeOnSurfaceVariant(ThemeData theme) =>
      theme.colorScheme.onSurfaceVariant;

  String _formatDate(DateTime at) =>
      '${at.day} ${_months[at.month - 1]} ${at.year}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _AppealDialog extends StatefulWidget {
  const _AppealDialog();

  @override
  State<_AppealDialog> createState() => _AppealDialogState();
}

class _AppealDialogState extends State<_AppealDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request a review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us why you think this is a mistake. We usually review '
            'appeals within 24 hours.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 600,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Explain what happened…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
