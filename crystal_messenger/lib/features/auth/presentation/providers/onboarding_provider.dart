import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_provider.freezed.dart';

@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(0) int currentStep,
    @Default('') String fullName,
    @Default('') String phone,
    String? avatarPath,
    @Default(false) bool isLoading,
  }) = _OnboardingState;
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setFullName(String name) => state = state.copyWith(fullName: name);
  void setPhone(String phone) => state = state.copyWith(phone: phone);
  void setAvatarPath(String? path) => state = state.copyWith(avatarPath: path);
  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);

  bool get canProceed {
    switch (state.currentStep) {
      case 0:
        return state.fullName.trim().length >= 2;
      case 1:
        return state.phone.trim().length >= 6;
      case 2:
        return true;
      default:
        return false;
    }
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
