import { View, Text, ScrollView, Pressable, Alert, StyleSheet, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';

import { Screen } from '@/components/Screen';
import { Button } from '@/components/Button';
import { Input } from '@/components/Input';
import { Avatar } from '@/components/Avatar';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';

export default function OnboardingScreen() {
  const router = useRouter();
  const { completeOnboarding, completeOnboardingState } = useAuth();

  const [fullName, setFullName] = useState('');
  const [phoneCode, setPhoneCode] = useState('+1');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [avatarUri, setAvatarUri] = useState<string | null>(null);
  const [nameError, setNameError] = useState('');
  const [phoneError, setPhoneError] = useState('');

  const validate = (): boolean => {
    let valid = true;
    setNameError('');
    setPhoneError('');

    if (!fullName.trim()) {
      setNameError('Full name is required');
      valid = false;
    }

    if (!phoneNumber.trim()) {
      setPhoneError('Phone number is required');
      valid = false;
    }

    return valid;
  };

  const handlePickAvatar = async () => {
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission needed', 'Please grant camera roll access to choose a profile picture.');
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });

    if (!result.canceled && result.assets[0]) {
      setAvatarUri(result.assets[0].uri);
    }
  };

  const handleSubmit = () => {
    if (!validate()) return;

    const fullPhone = `${phoneCode}${phoneNumber}`;
    Alert.alert(
      'Confirm Phone Number',
      `Is this number correct?\n${fullPhone}`,
      [
        { text: 'Edit', style: 'cancel' },
        {
          text: 'Yes',
          onPress: async () => {
            try {
              await completeOnboarding({
                fullName: fullName.trim(),
                phone: fullPhone,
                avatarUrl: avatarUri ?? undefined,
              });
              router.replace('/(app)/(tabs)');
            } catch {
              Alert.alert('Error', 'Failed to complete setup. Please try again.');
            }
          },
        },
      ]
    );
  };

  return (
    <Screen scrollable={false} padding="none" safeArea>
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.appIconContainer}>
          <View style={styles.appIcon}>
            <Ionicons name="chatbubble-ellipses" size={48} color={Colors.light.primary} />
          </View>
        </View>

        <Text style={styles.appName}>CRYSTAL MESSENGER</Text>
        <Text style={styles.appTagline}>Ultra-Clean, Next-Gen Secure Communications</Text>

        <Pressable style={styles.privacyLink}>
          <Ionicons name="shield-checkmark" size={16} color={Colors.light.primary} />
          <Text style={styles.privacyText}>Read our Privacy Matrix & Policy</Text>
        </Pressable>

        <View style={styles.divider} />

        <Text style={styles.formIntro}>
          Set up your profile to activate your identity on Crystal.
        </Text>

        <View style={styles.formSection}>
          <Input
            placeholder="Full Name"
            value={fullName}
            onChangeText={(text) => {
              setFullName(text);
              if (nameError) setNameError('');
            }}
            error={nameError}
            leftIcon={<Ionicons name="person-outline" size={20} color={Colors.light.textSecondary} />}
            containerStyle={styles.inputContainer}
            inputStyle={styles.inputField}
          />

          <View style={styles.phoneRow}>
            <View style={styles.codeContainer}>
              <Input
                placeholder="Code"
                value={phoneCode}
                onChangeText={setPhoneCode}
                keyboardType="phone-pad"
                leftIcon={<Text style={styles.flagIcon}>🏳️</Text>}
                containerStyle={styles.codeInputContainer}
                inputStyle={styles.codeInputField}
              />
            </View>
            <View style={styles.phoneContainer}>
              <Input
                placeholder="Phone Number"
                value={phoneNumber}
                onChangeText={(text) => {
                  setPhoneNumber(text);
                  if (phoneError) setPhoneError('');
                }}
                keyboardType="phone-pad"
                error={phoneError}
                leftIcon={<Ionicons name="call-outline" size={20} color={Colors.light.textSecondary} />}
                containerStyle={styles.phoneInputContainer}
                inputStyle={styles.phoneInputField}
              />
            </View>
          </View>
        </View>

        <View style={styles.avatarSection}>
          <View style={styles.avatarLabels}>
            <Text style={styles.avatarLabel}>CHOOSE YOUR AVATAR IDENTITY</Text>
            <Text style={styles.galleryLabel}>OR UPLOAD FROM GALLERY</Text>
          </View>

          <Pressable onPress={handlePickAvatar} style={styles.avatarPressable}>
            {avatarUri ? (
              <Avatar
                source={{ uri: avatarUri }}
                size="xl"
                showBorder
                borderColor={Colors.light.primary}
              />
            ) : (
              <View style={styles.avatarPlaceholder}>
                <Ionicons name="person" size={32} color={Colors.light.textSecondary} />
              </View>
            )}
          </Pressable>
        </View>

        <Button
          variant="primary"
          size="lg"
          fullWidth
          onPress={handleSubmit}
          loading={completeOnboardingState.isPending}
          disabled={completeOnboardingState.isPending}
          style={styles.submitButton}
        >
          {completeOnboardingState.isPending ? (
            <ActivityIndicator size="small" color={Colors.light.inverse} />
          ) : (
            'AGREE & CONTINUE'
          )}
        </Button>

        <Text style={styles.footerText}>
          Protected by Crystal LLC. End-to-End Encrypted Transit.
        </Text>
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scrollView: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  scrollContent: {
    flexGrow: 1,
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.xxl,
    paddingBottom: Spacing.xxl,
  },
  appIconContainer: {
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  appIcon: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: '#D4E4F7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  appName: {
    fontSize: 28,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
    textAlign: 'center',
    letterSpacing: 1,
    marginBottom: Spacing.xs,
  },
  appTagline: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.lg,
  },
  privacyLink: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    marginBottom: Spacing.lg,
  },
  privacyText: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.primary,
    fontWeight: Typography.fontWeight.medium,
  },
  divider: {
    width: '100%',
    height: 1,
    backgroundColor: Colors.light.border,
    marginBottom: Spacing.lg,
  },
  formIntro: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.lg,
    lineHeight: Typography.lineHeight.sm,
  },
  formSection: {
    width: '100%',
    gap: Spacing.md,
    marginBottom: Spacing.lg,
  },
  inputContainer: {
    width: '100%',
  },
  inputField: {
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.round,
    borderWidth: 0,
  },
  phoneRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  codeContainer: {
    flex: 0.35,
  },
  codeInputContainer: {
    flex: 1,
  },
  codeInputField: {
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.round,
    borderWidth: 0,
  },
  phoneContainer: {
    flex: 0.65,
  },
  phoneInputContainer: {
    flex: 1,
  },
  phoneInputField: {
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.round,
    borderWidth: 0,
  },
  flagIcon: {
    fontSize: 18,
  },
  avatarSection: {
    width: '100%',
    alignItems: 'center',
    marginBottom: Spacing.lg,
  },
  avatarLabels: {
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  avatarLabel: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.textSecondary,
    letterSpacing: 0.5,
  },
  galleryLabel: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.medium,
    color: Colors.light.textSecondary,
  },
  avatarPressable: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarPlaceholder: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: Colors.light.surfaceVariant,
    borderWidth: 2,
    borderColor: Colors.light.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  submitButton: {
    width: '100%',
    backgroundColor: '#D4E4F7',
    borderRadius: BorderRadius.round,
    minHeight: 52,
    marginBottom: Spacing.lg,
  },
  footerText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textTertiary,
    textAlign: 'center',
    lineHeight: Typography.lineHeight.xs,
  },
});
