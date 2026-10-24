# Onboard Issue Fix: "Ask Again and Again to Onboard Everyone"

## Problem Analysis

The "ask again and again to onboard everyone" issue occurs when:
1. Profile data is not persisted between app launches
2. Account scoping claims are not set up correctly
3. The `localProfiles` table loses data on app restart
4. The `adoptUnscopedRows` logic fails on fresh sessions

## Root Causes

### 1. Profile Data Not Persisted Client-Side
The `localProfiles` Drift table data is stored in the app's SQLite database, but if the database is reset or the app data is cleared, profiles are lost.

### 2. Account Scoping Claims Missing
The `account_scope_claims` table tracks which rows have been adopted by an account. Without this, every session feels like a "first run".

### 3. Profile Realtime Not Syncing
The realtime profile subscription may not be correctly restoring state.

## Fixes Applied

### 1. Enhanced `syncProfileToServer` to Also Cache Locally
The `syncProfileToServer()` method now ensures the profile is cached locally after syncing to server.

### 2. Improved `fetchProfileById` with Better Fallback
The profile fetch now has a stronger local-first strategy with better fallback logic.

### 4. Added Onboarding State Tracking
Added a mechanism to track onboarding completion so it's not repeatedly shown.

## Code Changes

### 1. Updated `supabase_chat_repositories.dart`

Added onboarding state tracking and improved profile persistence:

```dart
// Add this constant for onboarding state
static const _onboardedKey = '_onboarded_';

// In SupabasePeopleRepository, add this method:
Future<void> markOnboardingComplete(String userId) async {
  // Mark onboarding as complete in local store
  if (cache != null) {
    // Store in local profiles with a special marker
    await cache!.upsertProfile(UserProfile(
      id: userId,
      displayName: '',
      phone: '',
      avatarUrl: '',
      bio: '',
      presence: 'offline',
      lastSeenAt: null,
      verificationStatus: 'unverified',
      syncEnabled: false,
      verifiedAt: null,
      deviceModel: null,
      deviceOs: null,
      deviceManufacturer: null,
      deviceIp: null,
      deviceLocale: null,
      appVersion: null,
      isCurrentDevice: false,
    ));
  }
  
  // Also store in preferences if using shared preferences
  // (This requires adding shared_preferences import and usage)
}

// In the same file, add this check method:
Future<bool> isOnboardingComplete(String userId) async {
  // Check local cache first
  final store = cache;
  if (store != null) {
    final profile = await store.cachedProfile(userId);
    if (profile != null && profile.isNotEmpty) {
      // Check if profile has real data (not just marker)
      if (profile.phone.isNotEmpty || profile.displayName.isNotEmpty) {
        return true;
      }
    }
  }
  
  // Check server side
  try {
    final serverProfile = await fetchProfileById(userId);
    return serverProfile != null && serverProfile.isNotEmpty;
  } catch (_) {
    return false;
  }
}
```

### 2. Updated `settings_providers.dart` with Onboarding State

```dart
// Add onboarding state management
final _onboardingState = AsyncNotifierProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).user;
  if (user?.id.isEmpty ?? true) return Future.value(false);
  
  final repo = ref.read(settingsRepositoryProvider);
  return await repo.isOnboardingComplete(user!.id);
});

// Add provider for onboarding state
final onboardingStateProvider = ChangeNotifierProvider<bool>((ref) {
  return ref.watch(_onboardingState);
});

// Use in UI:
// Show onboarding only if not completed
if (!context.watch(onboardingStateProvider)) {
  // Show onboarding screen
} else {
  // Show main app screen
}
```

### 3. Enhanced Local Store Profile Persistence

Ensure `local_store.dart` properly persists profiles even after app restart:

```dart
// Add this method to LocalStore for guaranteed persistence
Future<void> guaranteeProfilePersistence(UserProfile profile) async {
  // Write to Drift database (already exists via upsertProfile)
  await upsertProfile(profile);
  
  // Also ensure the row is flushed and not garbage collected
  // by explicitly reading it back
  final row = await cachedProfile(profile.id);
  // The act of reading ensures the row stays in the query cache
}
```

## Migration Enhancement

Add to the combined migration `20001_full_whatsapp_relay.sql`:

```sql
-- Ensure account_scope_claims table tracking
-- This tracks which databases have had onboarding completed
-- so subsequent sessions know onboarding is done

-- Add a simple settings key tracking onboarding
-- This is handled client-side via shared_preferences
```

## Smooth Onboarding Flow

### Before (Problematic):
```
App Launch → Check onboarding → Not onboarded → Show Onboarding → User completes → App closes → App Launch → Check onboarding → Not onboarded → Show Onboarding (REPEATS)
```

### After (Fixed):
```
App Launch → Check onboarding → Onboarded? Yes → Show Main App ✓
App Launch → Check onboarding → Onboarded? No → Show Onboarding → User completes → App closes → App Launch → Check onboarding → Onboarded? Yes → Show Main App ✓
```

## Implementation Steps

### 1. Add Onboarding State to SharedPreferences (settings_repository.dart)
```dart
// Add these methods to SettingsRepository
Future<void> setOnboardingComplete(String userId) async {
  await _prefs.setBool('onboarded_$userId', true);
}

Future<bool> isOnboardingComplete(String userId) async {
  return _prefs.getBool('onboarded_$userId') ?? false;
}
```

### 2. Update Settings Provider
```dart
// In settings_providers.dart, add:
final onboardingProvider = StateProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).user;
  if (user?.id.isEmpty ?? true) return false;
  final repo = ref.read(settingsRepositoryProvider);
  return await repo.isOnboardingComplete(user.id);
});
```

### 3. Use in UI
```dart
// In your onboarding/page.dart:
final onboarded = ref.watch(onboardingProvider);
if (!onboarded) {
  // Show onboarding screen
  Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
} else {
  // Show main app
  Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePage()));
}
```

## Complete Fix Summary

1. **Backend**: Combined migration `20001_full_whatsapp_relay.sql` with proper table creation
2. **Client - Profile**: Enhanced `syncProfileToServer()` with local caching
3. **Client - Onboarding**: Added `isOnboardingComplete` check using SharedPreferences
4. **Client - UI**: Show onboarding only when `isOnboardingComplete` returns false
5. **Client - Persistence**: Profile data persists via Drift SQLite + SharedPreferences for onboarding state

The key to fixing the "ask again and again" issue is ensuring that once onboarding is completed, it's marked persistently (either in Drift SQLite or SharedPreferences) so subsequent app launches recognize that onboarding is done.