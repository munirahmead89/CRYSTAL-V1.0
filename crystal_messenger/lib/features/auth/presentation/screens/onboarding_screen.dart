import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final onboarding = ref.watch(onboardingProvider);

    if (authState.isAuthenticated && authState.isOnboarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/permissions');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= onboarding.currentStep
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Content
            Expanded(
              child: IndexedStack(
                index: onboarding.currentStep,
                children: [
                  _buildNameStep(context, ref, onboarding),
                  _buildPhoneStep(context, ref, onboarding),
                  _buildAvatarStep(context, ref, onboarding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep(BuildContext context, WidgetRef ref, OnboardingState onboarding) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.person_add, color: AppColors.primary, size: 48),
          const SizedBox(height: 24),
          const Text(
            'What\'s your name?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This will be visible to your contacts.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          AppInput(
            label: 'Full Name',
            hint: 'Enter your name',
            prefixIcon: Icons.person_outline,
            onChanged: (v) => ref.read(onboardingProvider.notifier).setFullName(v),
          ),
          const Spacer(),
          AppButton(
            label: 'Next',
            onPressed: onboarding.canProceed
                ? () => ref.read(onboardingProvider.notifier).nextStep()
                : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context, WidgetRef ref, OnboardingState onboarding) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.phone, color: AppColors.primary, size: 48),
          const SizedBox(height: 24),
          const Text(
            'What\'s your phone number?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll verify your number.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          AppInput(
            label: 'Phone Number',
            hint: '+1 234 567 8900',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            onChanged: (v) => ref.read(onboardingProvider.notifier).setPhone(v),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Back',
                  type: AppButtonType.secondary,
                  onPressed: () => ref.read(onboardingProvider.notifier).previousStep(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  label: 'Next',
                  onPressed: onboarding.canProceed
                      ? () => ref.read(onboardingProvider.notifier).nextStep()
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAvatarStep(BuildContext context, WidgetRef ref, OnboardingState onboarding) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.camera_alt, color: AppColors.primary, size: 48),
          const SizedBox(height: 24),
          const Text(
            'Add a profile photo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional but recommended.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 80,
              );
              if (image != null) {
                ref.read(onboardingProvider.notifier).setAvatarPath(image.path);
              }
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceVariant,
                border: Border.all(color: AppColors.primary.withAlpha(80), width: 3),
              ),
              child: onboarding.avatarPath != null
                  ? ClipOval(
                      child: Image.file(
                        File(onboarding.avatarPath!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: AppColors.textTertiary, size: 40),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Back',
                  type: AppButtonType.secondary,
                  onPressed: () => ref.read(onboardingProvider.notifier).previousStep(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  label: 'Complete',
                  isLoading: onboarding.isLoading,
                  onPressed: () => _completeOnboarding(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    final onboarding = ref.read(onboardingProvider);
    try {
      await ref.read(authProvider.notifier).completeOnboarding(
            fullName: onboarding.fullName,
            phone: onboarding.phone,
            avatarUrl: onboarding.avatarPath,
          );
      if (context.mounted) context.go('/permissions');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
