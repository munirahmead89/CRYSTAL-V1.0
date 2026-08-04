import { View, Text, Pressable, Alert, StyleSheet, Animated, Easing } from 'react-native';
import { useState, useEffect } from 'react';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '@/components/Screen';
import { Avatar } from '@/components/Avatar';
import { Button } from '@/components/Button';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';

export default function QrCodeScreen() {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<'mycode' | 'scan'>('mycode');
  const [scanLineAnim] = useState(() => new Animated.Value(0));

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(scanLineAnim, {
          toValue: 1,
          duration: 2000,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(scanLineAnim, {
          toValue: 0,
          duration: 2000,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ])
    );
    animation.start();
    return () => animation.stop();
  }, [scanLineAnim]);

  const handleShareCard = () => {
    Alert.alert('Share', 'Share functionality coming soon');
  };

  const handleSimulateScan = () => {
    Alert.alert('Success', 'Contact added! Starting chat...');
  };

  return (
    <Screen style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Crystal</Text>
        <View style={styles.headerRight}>
          <Pressable style={styles.iconButton}>
            <Ionicons name="camera-outline" size={24} color={Colors.light.text} />
          </Pressable>
          <Avatar
            size="sm"
            name={user?.fullName || 'U'}
          />
        </View>
      </View>

      <View style={styles.tabContainer}>
        <Pressable
          style={[styles.tab, activeTab === 'mycode' && styles.tabActive]}
          onPress={() => setActiveTab('mycode')}
        >
          <Text style={[styles.tabText, activeTab === 'mycode' && styles.tabTextActive]}>
            MY CODE
          </Text>
        </Pressable>
        <Pressable
          style={[styles.tab, activeTab === 'scan' && styles.tabActive]}
          onPress={() => setActiveTab('scan')}
        >
          <Text style={[styles.tabText, activeTab === 'scan' && styles.tabTextActive]}>
            SCAN CAMERA QR
          </Text>
        </Pressable>
      </View>

      {activeTab === 'mycode' ? (
        <View style={styles.content}>
          <Text style={styles.title}>My Identity Card</Text>
          <Text style={styles.subtitle}>
            Let others scan your custom QR code to instantly start secure chat sessions.
          </Text>

          <View style={styles.qrPlaceholder}>
            <Ionicons name="qr-code" size={120} color={Colors.light.background} />
          </View>

          <Text style={styles.name}>{user?.fullName || 'MUNIR WAHEED'}</Text>
          <Text style={styles.phone}>{user?.phone || '+92 3240941091'}</Text>

          <Button onPress={handleShareCard} style={styles.shareButton}>
            <Text style={styles.shareButtonText}>SHARE CARD ID</Text>
          </Button>
        </View>
      ) : (
        <View style={styles.content}>
          <Text style={styles.title}>Scan QR Code</Text>
          <Text style={styles.subtitle}>
            Aim your camera at another user&apos;s Crystal QR code to add them instantly.
          </Text>

          <View style={styles.viewfinder}>
            <Ionicons name="scan" size={80} color={Colors.light.text} />
            <Animated.View
              style={[
                styles.scanLine,
                {
                  transform: [
                    {
                      translateY: scanLineAnim.interpolate({
                        inputRange: [0, 1],
                        outputRange: [0, 240],
                      }),
                    },
                  ],
                },
              ]}
            />
          </View>

          <Button onPress={handleSimulateScan} style={styles.scanButton}>
            <View style={styles.scanButtonInner}>
              <Ionicons name="camera" size={20} color={Colors.light.background} />
              <Text style={styles.scanButtonText}>SIMULATE CAMERA QR SCAN</Text>
            </View>
          </Button>
        </View>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  headerTitle: {
    fontSize: Typography.fontSize.xxl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  headerRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
  },
  iconButton: {
    padding: Spacing.xs,
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.md,
    padding: 4,
    marginHorizontal: Spacing.lg,
    marginBottom: Spacing.xl,
  },
  tab: {
    flex: 1,
    paddingVertical: Spacing.sm,
    alignItems: 'center',
    borderRadius: BorderRadius.xl,
  },
  tabActive: {
    backgroundColor: '#D4E4F7',
  },
  tabText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textSecondary,
    fontWeight: Typography.fontWeight.semibold,
  },
  tabTextActive: {
    color: Colors.light.background,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
  },
  title: {
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
    textAlign: 'center',
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.xl,
    paddingHorizontal: Spacing.md,
  },
  qrPlaceholder: {
    width: 280,
    height: 280,
    backgroundColor: Colors.light.text,
    borderRadius: BorderRadius.xl,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  name: {
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
    textAlign: 'center',
    marginBottom: Spacing.xs,
  },
  phone: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.xl,
  },
  shareButton: {
    backgroundColor: '#D4E4F7',
    borderRadius: BorderRadius.xl,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    width: '100%',
  },
  shareButtonText: {
    color: Colors.light.background,
    fontWeight: Typography.fontWeight.semibold,
  },
  viewfinder: {
    width: 280,
    height: 280,
    backgroundColor: Colors.light.surface,
    borderRadius: BorderRadius.xl,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Spacing.xl,
    overflow: 'hidden',
  },
  scanLine: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 3,
    backgroundColor: Colors.light.primary,
  },
  scanButton: {
    backgroundColor: '#D4E4F7',
    borderRadius: BorderRadius.xl,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    width: '100%',
  },
  scanButtonInner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
  },
  scanButtonText: {
    color: Colors.light.background,
    fontWeight: Typography.fontWeight.semibold,
  },
});
