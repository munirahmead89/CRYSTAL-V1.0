import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/router.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/security/device_identity.dart';
import '../../../../native/device_info.dart';
import '../../../../features/conversations/presentation/providers/chat_providers.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/utils/phone_normalizer.dart';
import '../../../../shared/widgets/country_code_picker.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/auth_providers.dart';

/// "Welcome back" screen behind the LOGIN slide on the onboarding page.
///
/// Already-onboarded users who were asked to re-onboard (e.g. by an update)
/// never re-enter their details from scratch: they type the phone number they
/// onboarded with and the rest is brought back from the backend — display
/// name, avatar and bio are fetched and pre-filled for confirmation.
class RestoreProfilePage extends ConsumerStatefulWidget {
  const RestoreProfilePage({super.key});

  @override
  ConsumerState<RestoreProfilePage> createState() => _RestoreProfilePageState();
}

enum _RestorePhase { phone, confirm, notFound }

class _RestoreProfilePageState extends ConsumerState<RestoreProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _phoneFieldKey = GlobalKey<PhoneInputFieldState>();

  _RestorePhase _phase = _RestorePhase.phone;
  UserProfile? _found;
  bool _busy = false;
  String _searchedPhone = '';

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    final phoneState = _phoneFieldKey.currentState;
    if (phoneState != null) {
      return phoneState.fullPhoneNumber;
    }
    // Fallback: build from default country
    final dialCode = CountryCodes.defaultCountry.dialCode;
    final number = _phone.text.trim();
    if (number.isEmpty) return '';
    final normalized = number.startsWith('0') ? number.substring(1) : number;
    return '$dialCode$normalized';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Push/device registration. Never awaited, never throws — see the note at
  /// the call site.
  Future<void> _registerDevice() async {
    try {
      final deviceInfo = await ref.read(deviceInfoProvider.future);
      final notifications = ref.read(notificationServiceProvider);
      await ref
          .read(authRepositoryProvider)
          .registerDevice(
            deviceId: await DeviceIdentity.getOrCreate(),
            platform: notifications.platform,
            deviceName: deviceInfo?.label ?? 'default',
            pushToken: await notifications.token(),
            deviceModel: deviceInfo?.model,
            deviceOs: deviceInfo?.osVersion,
            deviceManufacturer: deviceInfo?.manufacturer,
            deviceIp: deviceInfo?.ipAddress,
            deviceLocale: deviceInfo?.locale,
            appVersion: deviceInfo?.appVersion,
          );
    } catch (_) {}
  }

  Future<void> _lookup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // A session is required for the phone lookup and the restore RPC.
      final notifier = ref.read(authControllerProvider.notifier);
      final already = ref.read(authStateProvider).isSignedIn;
      if (!already) {
        await notifier.signInAnonymously();
        final flow = ref.read(authControllerProvider);
        if (flow is AuthFlowError) {
          _snack(flow.message);
          setState(() => _busy = false);
          return;
        }
      }

      final phone = _fullPhoneNumber;
      _searchedPhone = phone;
      final profile = await ref
          .read(peopleRepositoryProvider)
          .fetchProfileByPhone(phone);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _phase = _RestorePhase.notFound;
          _busy = false;
        });
        return;
      }
      _name.text = profile.displayName;
      _bio.text = profile.bio;
      setState(() {
        _found = profile;
        _phase = _RestorePhase.confirm;
        _busy = false;
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not look up your account: ${e.message}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not look up your account. Check your connection.');
      }
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final phone = normalizePhoneForStorage(_phone.text.trim());
      final restored = await ref
          .read(peopleRepositoryProvider)
          .restoreProfileByPhone(phone);
      if (restored == null) throw StateError('Restore failed.');
      // Apply any edits made on the confirmation form on top of what the
      // backend restored.
      await ref
          .read(ownProfileProvider.notifier)
          .save(
            displayName: _name.text.trim(),
            phone: phone,
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            avatarUrl: restored.avatarUrl,
          );

      // Device registration is fire-and-forget: it resolves a hardware id, a
      // Firebase token and an RPC, and the user is waiting on a spinner. It can
      // also be rejected outright for a guest, so it must never gate entry.
      unawaited(_registerDevice());

      if (!mounted) return;
      context.goNamed(Routes.home);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not restore your account: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not restore your account. Try again.');
    }
  }

  void _startFresh() {
    context.go('/setup');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirm = _phase == _RestorePhase.confirm;
    final isNotFound = _phase == _RestorePhase.notFound;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome back')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isConfirm
                      ? Icons.verified_user_outlined
                      : (isNotFound
                            ? Icons.person_add_disabled
                            : Icons.smartphone),
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isConfirm
                      ? 'That looks like you'
                      : (isNotFound ? 'No profile found' : 'Log back in'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isConfirm
                      ? 'Welcome back! These details were found on your '
                            'saved profile — confirm and continue.'
                      : (isNotFound
                            ? 'No account was found for $_searchedPhone. Would you like to create a new profile?'
                            : 'Already onboarded? Enter the phone number '
                                  'you used and we will bring your saved '
                                  'details back.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (isConfirm && _found != null) ...[
                  // Routed through UserAvatar rather than a raw NetworkImage:
                  // the avatars bucket is private, so a stored public URL 404s
                  // and a signed URL has to be minted per render. This was the
                  // last site still bypassing that.
                  UserAvatar(profile: _found, radius: 44, online: null),
                  const SizedBox(height: 24),
                ],
                if (!isNotFound) ...[
                  PhoneInputField(
                    key: _phoneFieldKey,
                    controller: _phone,
                    initialCountry: CountryCodes.defaultCountry,
                    labelText: 'Phone number',
                    hintText: 'Enter your phone number',
                    enabled: !isConfirm,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your phone number'
                        : null,
                  ),
                ],
                if (isConfirm) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bio,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Bio (optional)',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (isNotFound) ...[
                  FilledButton(
                    onPressed: _startFresh,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'AGREE AND CONTINUE (CREATE NEW PROFILE)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _phase = _RestorePhase.phone;
                      _phone.clear();
                    }),
                    child: const Text('Try a different phone number'),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed: _busy ? null : (isConfirm ? _confirm : _lookup),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isConfirm ? 'AGREE AND CONTINUE' : 'Look up'),
                  ),
                  if (isConfirm)
                    TextButton(
                      onPressed: _busy ? null : _startFresh,
                      child: const Text('New here? Set up a new profile'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
