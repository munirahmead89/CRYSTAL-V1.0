import { View, Text, Alert, Pressable, StyleSheet } from 'react-native';
import { useState } from 'react';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';

import { Screen } from '@/components/Screen';
import { Card } from '@/components/Card';
import { Button } from '@/components/Button';
import { Avatar } from '@/components/Avatar';
import { Divider } from '@/components/Divider';
import { Input } from '@/components/Input';
import { Spinner } from '@/components/Spinner';
import { Colors, Spacing, Typography } from '@/theme';
import { useAuth } from '@/hooks/useAuth';
import { logger } from '@/utils/logger';

export default function ProfileScreen() {
  const { user, updateProfile, updateProfileState, uploadAvatar, uploadAvatarState, logout } = useAuth();
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({
    fullName: user?.fullName || '',
    bio: user?.bio || '',
  });

  const handlePickImage = async () => {
    try {
      const permissionResult = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permissionResult.granted) {
        Alert.alert('Permission Required', 'Access to media library is needed to upload profile pictures.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.6,
      });

      if (result.canceled || !result.assets || result.assets.length === 0) {
        return;
      }

      const selectedUri = result.assets?.[0]?.uri;
      if (!selectedUri) {
        return;
      }

      await uploadAvatar(selectedUri);
      Alert.alert('Saved', 'Avatar updated successfully');
    } catch (error) {
      logger.error('Error picking image', {}, error as Error);
      Alert.alert('Error', 'Failed to upload avatar image');
    }
  };

  const handleSave = async () => {
    try {
      await updateProfile(formData);
      setIsEditing(false);
      Alert.alert('Saved', 'Profile updated successfully');
    } catch (error) {
      logger.error('Profile update error', {}, error as Error);
      Alert.alert('Error', 'Failed to update profile');
    }
  };

  const handleCancel = () => {
    setFormData({
      fullName: user?.fullName || '',
      bio: user?.bio || '',
    });
    setIsEditing(false);
  };

  return (
    <Screen scrollable={true} padding="lg" safeArea={true}>
      <View style={styles.container}>
        <View style={styles.profileHeader}>
          <Pressable onPress={handlePickImage} disabled={uploadAvatarState.isPending} style={styles.avatarPressable}>
            <View style={styles.avatarWrapper}>
              <Avatar
                source={user?.avatarUrl ? { uri: user.avatarUrl } : undefined}
                name={user?.fullName}
                size="xxl"
                showBorder
                borderColor={Colors.light.background}
              />
              {uploadAvatarState.isPending ? (
                <View style={styles.avatarLoader}>
                  <Spinner size="large" color="#FFFFFF" />
                </View>
              ) : (
                <View style={styles.cameraIconContainer}>
                  <Ionicons name="camera" size={18} color="#FFFFFF" />
                </View>
              )}
            </View>
          </Pressable>
          <View style={styles.nameContainer}>
            <Text style={styles.fullName}>{formData.fullName || 'No name set'}</Text>
          </View>
        </View>

        <Card style={styles.infoCard} padding="lg" variant="outlined">
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>About</Text>
            {isEditing ? (
              <Input
                label="Bio"
                placeholder="Tell others about yourself"
                value={formData.bio}
                onChangeText={text => setFormData(prev => ({ ...prev, bio: text }))}
                multiline
                numberOfLines={4}
                containerStyle={styles.bioInput}
              />
            ) : (
              <Text style={styles.bioText}>
                {formData.bio || 'No bio yet. Tap edit to add one.'}
              </Text>
            )}
          </View>

          <Divider style={styles.divider} />

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Contact Info</Text>
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Email</Text>
              <Text style={styles.infoValue}>{user?.email}</Text>
            </View>
            {user?.phone && (
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Phone</Text>
                <Text style={styles.infoValue}>{user.phone}</Text>
              </View>
            )}
          </View>
        </Card>

        <Card style={styles.editCard} padding="lg" variant="outlined">
          {isEditing ? (
            <>
              <Input
                label="Full Name"
                value={formData.fullName}
                onChangeText={text => setFormData(prev => ({ ...prev, fullName: text }))}
                error={!formData.fullName ? 'Name is required' : undefined}
              />
              <View style={styles.buttonRow}>
                <Button
                  variant="outline"
                  onPress={handleCancel}
                  fullWidth
                >
                  Cancel
                </Button>
                <Button
                  onPress={handleSave}
                  fullWidth
                  loading={updateProfileState.isPending}
                  disabled={updateProfileState.isPending}
                >
                  Save
                </Button>
              </View>
            </>
          ) : (
            <Button
              variant="outline"
              onPress={() => setIsEditing(true)}
              fullWidth
            >
              Edit Profile
            </Button>
          )}
        </Card>

        <Card style={styles.dangerCard} padding="lg" variant="outlined">
          <Button
            variant="danger"
            fullWidth
            onPress={() => {
              Alert.alert('Logout', 'Are you sure you want to logout?', [
                { text: 'Cancel', style: 'cancel' },
                { text: 'Logout', style: 'destructive', onPress: () => { void logout(); } },
              ]);
            }}
          >
            Logout
          </Button>
        </Card>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: Spacing.xl,
  },
  profileHeader: {
    alignItems: 'center',
    gap: Spacing.md,
    paddingTop: Spacing.lg,
  },
  avatarPressable: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarWrapper: {
    position: 'relative',
  },
  avatarLoader: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.4)',
    borderRadius: 9999,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cameraIconContainer: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    backgroundColor: Colors.light.primary,
    borderRadius: 9999,
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: Colors.light.background,
  },
  nameContainer: {
    alignItems: 'center',
    gap: Spacing.xs,
  },
  fullName: {
    fontSize: Typography.fontSize.xxl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  infoCard: {
    gap: Spacing.md,
  },
  editCard: {
    gap: Spacing.md,
  },
  dangerCard: {},
  section: {
    gap: Spacing.sm,
  },
  sectionTitle: {
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.textSecondary,
    textTransform: 'uppercase',
  },
  bioInput: {
    marginTop: Spacing.xs,
  },
  bioText: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.text,
    lineHeight: Typography.lineHeight.md,
  },
  divider: {
    marginVertical: Spacing.md,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: Spacing.xs,
  },
  infoLabel: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
  },
  infoValue: {
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.medium,
    color: Colors.light.text,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginTop: Spacing.md,
  },
});