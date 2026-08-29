import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  File? _avatarFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    _nameController = TextEditingController(
      text: user?.userMetadata?['full_name'] ?? '',
    );
    _bioController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final profile = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _bioController.text = profile['bio'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);
    final user = client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),

          // Avatar
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  _avatarFile != null
                      ? ClipOval(
                          child: Image.file(
                            _avatarFile!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const AppAvatar(
                          name: 'Me',
                          size: 120,
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Name
          AppInput(
            label: 'Name',
            controller: _nameController,
            prefixIcon: Icons.person_outline,
          ),

          const SizedBox(height: 16),

          // Bio
          AppInput(
            label: 'About',
            controller: _bioController,
            prefixIcon: Icons.info_outline,
            hint: 'Hey there! I am using Crystal Messenger',
            maxLines: 3,
          ),

          const SizedBox(height: 32),

          // Phone
          ListTile(
            leading: const Icon(Icons.phone, color: AppColors.primary),
            title: const Text('Phone', style: TextStyle(color: AppColors.textSecondary)),
            subtitle: Text(
              user?.userMetadata?['phone'] ?? 'Not set',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),

          const SizedBox(height: 32),

          AppButton(
            label: 'Save Profile',
            isLoading: _isLoading,
            onPressed: _saveProfile,
          ),

          const SizedBox(height: 16),

          // QR Code
          AppButton(
            label: 'My QR Code',
            type: AppButtonType.secondary,
            icon: Icons.qr_code,
            onPressed: () => context.push('/qr-code'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _avatarFile = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser!.id;

      String? avatarUrl;
      if (_avatarFile != null) {
        final ext = _avatarFile!.path.split('.').last;
        final path = '$userId/avatar.$ext';
        await client.storage.from('avatars').upload(
              path,
              _avatarFile!,
              fileOptions: const FileOptions(upsert: true),
            );
        avatarUrl = 'avatars/$path';
      }

      await client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
