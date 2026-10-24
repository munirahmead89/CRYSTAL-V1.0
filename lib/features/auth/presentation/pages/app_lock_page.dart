import 'package:crystal_messenger/app/theme/app_theme.dart';
import 'package:crystal_messenger/core/security/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The screen shown while the app is locked.
///
/// Replaces the previous behaviour, which called the system biometric prompt
/// from a lifecycle callback and ignored the answer: the chat list was fully
/// rendered and interactive behind the dialog, so dismissing it left the app
/// unlocked, and a cold start never prompted at all.
///
/// This screen is a real gate. Content behind it is never built, and the user
/// leaves only through an explicit successful unlock (or the documented
/// fallback when the device has no usable screen lock).
class AppLockPage extends ConsumerStatefulWidget {
  const AppLockPage({super.key, this.onUnlocked});

  /// Invoked after a successful unlock so the router can leave this route.
  final VoidCallback? onUnlocked;

  @override
  ConsumerState<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends ConsumerState<AppLockPage> {
  @override
  void initState() {
    super.initState();
    // Prompt once on arrival. The controller de-duplicates, so the lifecycle
    // resumed that fires when the dialog opens cannot stack a second one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    final lock = ref.read(appLockControllerProvider);
    final outcome = await lock.unlock();
    if (!mounted) return;

    switch (outcome) {
      case UnlockOutcome.success:
        widget.onUnlocked?.call();
      case UnlockOutcome.unavailable:
        // Nothing to unlock with. Showing a lock the user cannot open would
        // strand them, so fall through rather than trap them.
        widget.onUnlocked?.call();
      case UnlockOutcome.cancelled:
      case UnlockOutcome.error:
        // Stay locked; the error message (if any) is rendered below.
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The app's speech-bubble mark, matching the welcome screen.
                Icon(
                  Icons.chat_bubble,
                  size: 76,
                  color: CrystalColors.greenDark,
                ),
                const SizedBox(height: 24),
                Text(
                  'Crystal Messenger',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lock.isAuthenticating
                      ? 'Waiting for your screen lock…'
                      : 'Locked',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                if (lock.isAuthenticating)
                  const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  FilledButton.icon(
                    onPressed: _attempt,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 48),
                    ),
                  ),

                if (lock.lastError != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    lock.lastError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                Text(
                  'Your chats are hidden until you unlock.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
