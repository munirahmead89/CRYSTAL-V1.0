import { View, Text, ScrollView, Pressable, Alert, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Ionicons } from '@expo/vector-icons';

import { Screen } from '@/components/Screen';
import { Button } from '@/components/Button';
import { Input } from '@/components/Input';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';
import { useContacts } from '@/hooks/useContacts';

export default function NewContactScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { addContact, addContactState } = useContacts(user?.id);

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [status, setStatus] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [nameError, setNameError] = useState('');
  const [phoneError, setPhoneError] = useState('');

  const validate = (): boolean => {
    let valid = true;
    setNameError('');
    setPhoneError('');

    if (!name.trim()) {
      setNameError('Name is required');
      valid = false;
    }

    if (!phone.trim()) {
      setPhoneError('Phone number is required');
      valid = false;
    }

    return valid;
  };

  const handleSave = async () => {
    if (!validate()) return;

    try {
      await addContact({
        phone: phone.trim(),
        displayName: name.trim(),
      });

      Alert.alert('Success', 'Contact added successfully');
      router.back();
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'Failed to save contact';
      Alert.alert('Error', message);
    }
  };

  const handleCancel = () => {
    router.back();
  };

  return (
    <Screen scrollable={false} padding="none" safeArea>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>New Contact</Text>
        <Pressable onPress={handleCancel} style={styles.backButton}>
          <Ionicons name="arrow-forward" size={22} color={Colors.light.text} />
        </Pressable>
      </View>

      <View style={styles.headerDivider} />

      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.formSection}>
          <Input
            label="Name"
            placeholder="Contact name"
            value={name}
            onChangeText={(text) => {
              setName(text);
              if (nameError) setNameError('');
            }}
            error={nameError}
            containerStyle={styles.inputContainer}
            inputStyle={styles.inputField}
          />

          <Input
            label="Phone Number"
            placeholder="+1 234 567 8900"
            value={phone}
            onChangeText={(text) => {
              setPhone(text);
              if (phoneError) setPhoneError('');
            }}
            keyboardType="phone-pad"
            error={phoneError}
            containerStyle={styles.inputContainer}
            inputStyle={styles.inputField}
          />

          <Input
            label="Status text"
            placeholder="What's on your mind?"
            value={status}
            onChangeText={setStatus}
            containerStyle={styles.inputContainer}
            inputStyle={styles.inputField}
          />

          <Input
            label="Avatar URL (optional)"
            placeholder="https://example.com/avatar.jpg"
            value={avatarUrl}
            onChangeText={setAvatarUrl}
            keyboardType="url"
            autoCapitalize="none"
            containerStyle={styles.inputContainer}
            inputStyle={styles.inputField}
          />
        </View>
      </ScrollView>

      <View style={styles.bottomBar}>
        <Pressable onPress={handleCancel} style={styles.cancelButton}>
          <Text style={styles.cancelText}>Cancel</Text>
        </Pressable>
        <Button
          variant="primary"
          onPress={handleSave}
          loading={addContactState.isPending}
          disabled={addContactState.isPending}
          style={styles.saveButton}
        >
          Save
        </Button>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
  },
  headerTitle: {
    fontSize: Typography.fontSize.xl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  backButton: {
    padding: Spacing.xs,
  },
  headerDivider: {
    height: 1,
    backgroundColor: Colors.light.border,
  },
  scrollView: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
  formSection: {
    gap: Spacing.md,
  },
  inputContainer: {
    width: '100%',
  },
  inputField: {
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.round,
    borderWidth: 1,
    borderColor: Colors.light.border,
  },
  bottomBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: Spacing.md,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.light.border,
  },
  cancelButton: {
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.md,
  },
  cancelText: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
    fontWeight: Typography.fontWeight.medium,
  },
  saveButton: {
    minWidth: 100,
    backgroundColor: Colors.light.primary,
    borderRadius: BorderRadius.round,
  },
});
