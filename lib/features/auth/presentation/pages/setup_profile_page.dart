import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/network/supabase_providers.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/security/device_identity.dart';
import '../../../../native/device_info.dart';
import '../../../../shared/utils/phone_normalizer.dart';
import '../../../../shared/widgets/avatar_source.dart';
import '../../../../shared/widgets/country_code_picker.dart';
import '../providers/auth_providers.dart';

class SetupProfilePage extends ConsumerStatefulWidget {
  const SetupProfilePage({super.key});

  @override
  ConsumerState<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends ConsumerState<SetupProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  final _phoneFieldKey = GlobalKey<PhoneInputFieldState>();

  File? _imageFile;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Push/device registration for cross-device sync and call notifications.
  ///
  /// Never awaited by the caller and never throws: it resolves a hardware id,
  /// a Firebase token and an RPC, all of which can fail or stall, and none of
  /// which is a precondition for reaching the app.
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
    } catch (_) {
      // Guest accounts and offline devices are both expected here.
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    // A picked file is only ever present on a real device. Guarded so the
    // profile save never depends on storage being reachable: an avatar is
    // decoration, and failing it must not block onboarding.
    if (_imageFile == null) return null;
    try {
      final supabase = ref.read(supabaseClientProvider);
      // Path is relative to the bucket. `from('avatars')` already selects it,
      // so prefixing 'avatars/' again stored the object at
      // `avatars/avatars/...` and the returned public URL 400'd — the profile
      // saved with a broken avatar and no error surfaced.
      //
      // The bare path is stored because the bucket is private; UserAvatar
      // resolves it to a signed URL at render time.
      final path = '$userId/avatar.jpg';
      await supabase.storage
          .from(kAvatarBucket)
          .upload(
            path,
            _imageFile!,
            fileOptions: const FileOptions(upsert: true),
          );
      return '$path?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (error) {
      debugPrint('Avatar upload failed: $error');
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      _snack('Please select a profile picture to continue.');
      return;
    }
    setState(() => _saving = true);

    try {
      var user = ref.read(authRepositoryProvider).currentUser;
      if (user == null || user.id.isEmpty) {
        // Automatically re-authenticate anonymously if session was dropped
        await ref.read(authControllerProvider.notifier).signInAnonymously();
        user = ref.read(authRepositoryProvider).currentUser;
      }

      final userId = user?.id ?? '';
      final rawPhone = _fullPhoneNumber;
      if (rawPhone.trim().isEmpty) {
        _snack('Enter a phone number to continue.');
        setState(() => _saving = false);
        return;
      }
      final phone = normalizePhoneForStorage(rawPhone);
      final name = _name.text.trim();
      final bioText = _bio.text.trim().isEmpty ? null : _bio.text.trim();

      String? avatarUrl;
      if (userId.isNotEmpty) {
        avatarUrl = await _uploadAvatar(userId);
      }

      final notifier = ref.read(ownProfileProvider.notifier);

      try {
        await notifier.save(
          displayName: name,
          phone: phone,
          bio: bioText,
          avatarUrl: avatarUrl,
        );
      } catch (dbError) {
        // Keep the draft local for the next attempt, but do not enter the app
        // shell without a server profile: conversations need a real identity.
        notifier.applyLocally(
          displayName: name,
          phone: phone,
          bio: bioText,
          avatarUrl: avatarUrl,
        );
        rethrow;
      }

      unawaited(_registerDevice());

      if (!mounted) return;
      context.goNamed(Routes.home);
    } catch (e) {
      // Preserve the draft locally, but require a successful server write
      // before onboarding can complete.
      final rawPhone = _fullPhoneNumber;
      final phone = rawPhone.isNotEmpty
          ? normalizePhoneForStorage(rawPhone)
          : '';
      final name = _name.text.trim();
      if (name.isNotEmpty && phone.isNotEmpty) {
        ref
            .read(ownProfileProvider.notifier)
            .applyLocally(
              displayName: name,
              phone: phone,
              bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            );
        if (mounted) _snack('Could not sync your profile. Check your connection and try again.');
      } else if (mounted) {
        _snack('Enter your name and phone number to continue.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? CrystalColors.white12
                          : CrystalColors.black12,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : null,
                      child: _imageFile == null
                          ? Icon(
                              Icons.person,
                              size: 56,
                              color: theme.colorScheme.outline,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.black,
                          ),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Set your profile picture',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                PhoneInputField(
                  key: _phoneFieldKey,
                  controller: _phone,
                  initialCountry: CountryCodes.defaultCountry,
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bio,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Bio (optional)',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('AGREE AND CONTINUE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
