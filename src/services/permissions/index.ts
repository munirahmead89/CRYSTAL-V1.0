import { Alert, Linking } from 'react-native';
import * as Notifications from 'expo-notifications';
import * as ImagePicker from 'expo-image-picker';

export interface PermissionStatus {
  granted: boolean;
  canAskAgain: boolean;
}

export async function requestNotificationPermission(): Promise<PermissionStatus> {
  const { status } = await Notifications.requestPermissionsAsync();
  return { granted: status === 'granted', canAskAgain: status !== 'denied' };
}

export async function requestMediaLibraryPermission(): Promise<PermissionStatus> {
  const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
  return { granted: status === 'granted', canAskAgain: status !== 'denied' };
}

export async function requestCameraPermission(): Promise<PermissionStatus> {
  const { status } = await ImagePicker.requestCameraPermissionsAsync();
  return { granted: status === 'granted', canAskAgain: status !== 'denied' };
}

export async function requestAllPermissions(): Promise<{
  notifications: PermissionStatus;
  camera: PermissionStatus;
  mediaLibrary: PermissionStatus;
}> {
  const [notifications, camera, mediaLibrary] = await Promise.all([
    requestNotificationPermission(),
    requestCameraPermission(),
    requestMediaLibraryPermission(),
  ]);

  return { notifications, camera, mediaLibrary };
}

export function showPermissionDeniedAlert(permission: string) {
  Alert.alert(
    'Permission Required',
    `${permission} access is needed for this feature. Please enable it in Settings.`,
    [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Open Settings', onPress: () => Linking.openSettings() },
    ]
  );
}
