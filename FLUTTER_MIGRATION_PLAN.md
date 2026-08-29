# Crystal Messenger — React Native → Flutter Migration Plan

## Executive Summary

Complete migration of Crystal Messenger from React Native (Expo SDK 57) to Flutter, preserving all existing features, Supabase backend, and Erlang real-time server. The Flutter version will use Riverpod for state management, GoRouter for navigation, and maintain the same WhatsApp-like UX with a clean layered architecture.

---

## TABLE OF CONTENTS

1. [Tech Stack Mapping](#1-tech-stack-mapping)
2. [Project Structure](#2-project-structure)
3. [Phase 1: Foundation](#3-phase-1-foundation)
4. [Phase 2: Core Features](#4-phase-2-core-features)
5. [Phase 3: Advanced Features](#5-phase-3-advanced-features)
6. [Phase 4: Polish & Deploy](#6-phase-4-polish--deploy)
7. [State Management (Zustand → Riverpod)](#7-state-management)
8. [Backend & Deployment](#8-backend--deployment)
9. [Seamless Update Strategy](#9-seamless-update-strategy)

---

## 1. TECH STACK MAPPING

| React Native | Flutter Equivalent | Package |
|---|---|---|
| Zustand | Riverpod | `flutter_riverpod` + `riverpod_annotation` |
| TanStack Query | Riverpod + AsyncNotifier | `riverpod` built-in |
| Expo Router | GoRouter | `go_router` |
| react-hook-form + zod | Flutter Form + Formz | `formz` + custom validators |
| @supabase/supabase-js | supabase_flutter | `supabase_flutter` |
| react-native-webrtc | flutter_webrtc | `flutter_webrtc` |
| expo-sqlite | drift (type-safe SQLite) | `drift` + `sqlite3_flutter_libs` |
| expo-secure-store | flutter_secure_storage | `flutter_secure_storage` |
| expo-notifications | firebase_messaging + flutter_local_notifications | `firebase_messaging` + `flutter_local_notifications` |
| expo-image-picker | image_picker | `image_picker` |
| expo-camera | camera | `camera` |
| expo-contacts | flutter_contacts | `flutter_contacts` |
| expo-file-system | path_provider + dio | `path_provider` + `dio` |
| react-native-reanimated | Flutter built-in animations | Implicit + Explicit animations |
| react-native-gesture-handler | Flutter built-in gestures | GestureDetector + Dismissible |
| expo-image | cached_network_image | `cached_network_image` |
| react-native-qrcode-svg | qr_flutter | `qr_flutter` |
| expo-audio | just_audio + record | `just_audio` + `record` |
| expo-video | video_player / chewie | `video_player` + `chewie` |
| react-native-svg | flutter_svg | `flutter_svg` |
| date-fns | intl | `intl` built-in |
| clsx / tailwind-merge | No needed (Dart classes) | N/A |
| @react-native-community/netinfo | connectivity_plus | `connectivity_plus` |
| expo-background-task | workmanager | `workmanager` |
| expo-haptics | flutter_haptic_feedback | `flutter_haptic_feedback` |
| expo-blink / expo-blur | BackdropFilter | Built-in |
| expo-localization | flutter_localizations | Built-in |
| TypeScript | Dart | Built-in |
| Jest | flutter_test + mocktail | Built-in + `mocktail` |
| ESLint + Prettier | dart analyze + dartfmt | Built-in |

---

## 2. PROJECT STRUCTURE

```
crystal_messenger/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── app/
│   │   ├── app.dart                       # MaterialApp.router + providers
│   │   ├── router.dart                    # GoRouter config + route guards
│   │   └── observer.dart                  # Navigation observer
│   │
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_theme.dart             # ThemeData (dark/light)
│   │   │   ├── app_colors.dart            # Color constants
│   │   │   ├── app_text_styles.dart       # Typography
│   │   │   └── app_spacing.dart           # Spacing/border radius
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # Limits, regex, etc.
│   │   │   └── api_constants.dart         # URLs, timeouts
│   │   ├── utils/
│   │   │   ├── logger.dart                # Logging utility
│   │   │   ├── id_generator.dart          # UUID generation
│   │   │   ├── date_utils.dart            # Date formatting
│   │   │   ├── validators.dart            # Form validation
│   │   │   └── helpers.dart               # General helpers
│   │   ├── extensions/
│   │   │   ├── string_extensions.dart
│   │   │   ├── datetime_extensions.dart
│   │   │   └── context_extensions.dart
│   │   └── errors/
│   │       ├── app_exception.dart         # Custom exceptions
│   │       └── error_handler.dart         # Global error handling
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── repositories/
│   │   │   │   │   └── auth_repository.dart
│   │   │   │   └── datasources/
│   │   │   │       └── auth_remote_source.dart
│   │   │   ├── domain/
│   │   │   │   ├── models/
│   │   │   │   │   ├── auth_user.dart
│   │   │   │   │   └── auth_session.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── sign_in_anonymous.dart
│   │   │   │       ├── complete_onboarding.dart
│   │   │   │       └── sign_out.dart
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   ├── auth_provider.dart
│   │   │   │   │   └── onboarding_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   ├── splash_screen.dart
│   │   │   │   │   ├── onboarding_screen.dart
│   │   │   │   │   └── permissions_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── animated_diamond.dart
│   │   │   │       └── onboarding_step.dart
│   │   │   └── auth.dart                  # Barrel export
│   │   │
│   │   ├── chat/
│   │   │   ├── data/
│   │   │   │   ├── repositories/
│   │   │   │   │   ├── chat_repository.dart
│   │   │   │   │   └── message_repository.dart
│   │   │   │   └── datasources/
│   │   │   │       ├── chat_remote_source.dart
│   │   │   │       └── chat_local_source.dart  # Drift DB
│   │   │   ├── domain/
│   │   │   │   ├── models/
│   │   │   │   │   ├── chat.dart
│   │   │   │   │   ├── message.dart
│   │   │   │   │   └── chat_participant.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── get_chats.dart
│   │   │   │       ├── send_message.dart
│   │   │   │       ├── mark_read.dart
│   │   │   │       └── delete_message.dart
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   ├── chat_list_provider.dart
│   │   │   │   │   ├── chat_detail_provider.dart
│   │   │   │   │   ├── message_provider.dart
│   │   │   │   │   └── typing_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   ├── chat_list_screen.dart
│   │   │   │   │   └── chat_detail_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── chat_tile.dart
│   │   │   │       ├── message_bubble.dart
│   │   │   │       ├── reply_preview.dart
│   │   │   │       ├── voice_note_bubble.dart
│   │   │   │       ├── video_message_bubble.dart
│   │   │   │       ├── typing_indicator.dart
│   │   │   │       ├── swipeable_chat_row.dart
│   │   │   │       └── chat_action_sheet.dart
│   │   │   └── chat.dart
│   │   │
│   │   ├── contacts/
│   │   │   ├── data/
│   │   │   │   ├── repositories/
│   │   │   │   │   └── contacts_repository.dart
│   │   │   │   └── datasources/
│   │   │   │       ├── contacts_remote_source.dart
│   │   │   │       └── contacts_local_source.dart
│   │   │   ├── domain/
│   │   │   │   └── models/
│   │   │   │       └── contact.dart
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   └── contacts_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   ├── contacts_screen.dart
│   │   │   │   │   ├── contact_detail_screen.dart
│   │   │   │   │   └── new_contact_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       └── contact_tile.dart
│   │   │   └── contacts.dart
│   │   │
│   │   ├── calls/
│   │   │   ├── data/
│   │   │   │   ├── repositories/
│   │   │   │   │   └── call_repository.dart
│   │   │   │   └── datasources/
│   │   │   │       └── call_remote_source.dart
│   │   │   ├── domain/
│   │   │   │   └── models/
│   │   │   │       ├── call.dart
│   │   │   │       └── call_participant.dart
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   ├── call_provider.dart
│   │   │   │   │   └── call_history_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   ├── call_history_screen.dart
│   │   │   │   │   └── call_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── call_tile.dart
│   │   │   │       ├── call_video_view.dart
│   │   │   │       └── call_controls.dart
│   │   │   └── calls.dart
│   │   │
│   │   ├── status/
│   │   │   ├── data/
│   │   │   │   ├── repositories/
│   │   │   │   │   └── status_repository.dart
│   │   │   │   └── datasources/
│   │   │   │       └── status_remote_source.dart
│   │   │   ├── domain/
│   │   │   │   └── models/
│   │   │   │       ├── status.dart
│   │   │   │       └── status_view.dart
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   └── status_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   ├── updates_screen.dart
│   │   │   │   │   ├── status_compose_screen.dart
│   │   │   │   │   └── status_viewer_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── status_ring.dart
│   │   │   │       └── status_strip.dart
│   │   │   └── status.dart
│   │   │
│   │   ├── profile/
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   └── profile_provider.dart
│   │   │   │   └── screens/
│   │   │   │       └── profile_screen.dart
│   │   │   └── widgets/
│   │   │       └── avatar_widget.dart
│   │   │
│   │   ├── settings/
│   │   │   ├── presentation/
│   │   │   │   ├── providers/
│   │   │   │   │   └── settings_provider.dart
│   │   │   │   ├── screens/
│   │   │   │   │   ├── settings_screen.dart
│   │   │   │   │   ├── account_screen.dart
│   │   │   │   │   ├── privacy_screen.dart
│   │   │   │   │   ├── appearance_screen.dart
│   │   │   │   │   ├── chat_settings_screen.dart
│   │   │   │   │   ├── notification_settings_screen.dart
│   │   │   │   │   ├── storage_screen.dart
│   │   │   │   │   └── language_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── setting_row.dart
│   │   │   │       └── settings_scaffold.dart
│   │   │   └── settings.dart
│   │   │
│   │   ├── qr_code/
│   │   │   ├── presentation/
│   │   │   │   └── screens/
│   │   │   │       └── qr_code_screen.dart
│   │   │   └── utils/
│   │   │       └── qr_encoder.dart
│   │   │
│   │   └── shared/
│   │       └── widgets/
│   │           ├── app_avatar.dart
│   │           ├── app_button.dart
│   │           ├── app_card.dart
│   │           ├── app_divider.dart
│   │           ├── app_input.dart
│   │           ├── app_header_bar.dart
│   │           ├── app_spinner.dart
│   │           ├── error_boundary.dart
│   │           └── dropdown_menu.dart
│   │
│   ├── services/
│   │   ├── realtime/
│   │   │   ├── crystal_socket.dart          # Erlang WS client
│   │   │   └── crystal_socket_provider.dart  # Riverpod provider
│   │   ├── rtc/
│   │   │   ├── call_signaling.dart
│   │   │   └── web_rtc_session.dart
│   │   ├── offline/
│   │   │   ├── local_database.dart          # Drift database
│   │   │   └── offline_queue.dart
│   │   ├── network/
│   │   │   └── network_service.dart
│   │   ├── presence/
│   │   │   └── presence_service.dart
│   │   ├── push/
│   │   │   ├── push_notification_service.dart
│   │   │   └── background_refresh.dart
│   │   ├── media/
│   │   │   ├── media_url_resolver.dart
│   │   │   ├── media_uploader.dart
│   │   │   └── media_downloader.dart
│   │   ├── contacts/
│   │   │   └── contact_sync_service.dart
│   │   ├── audio/
│   │   │   ├── voice_recorder.dart
│   │   │   └── system_sounds.dart
│   │   └── storage/
│   │       └── secure_storage_service.dart
│   │
│   ├── database/
│   │   ├── app_database.dart                # Drift database definition
│   │   ├── tables/
│   │   │   ├── chats_table.dart
│   │   │   ├── messages_table.dart
│   │   │   ├── contacts_table.dart
│   │   │   └── pending_actions_table.dart
│   │   └── daos/
│   │       ├── chat_dao.dart
│   │       ├── message_dao.dart
│   │       └── contact_dao.dart
│   │
│   ├── providers/
│   │   ├── app_providers.dart               # ProviderScope
│   │   ├── supabase_provider.dart
│   │   ├── database_provider.dart
│   │   └── shared_preferences_provider.dart
│   │
│   └── models/                              # Shared data models
│       ├── chat.dart
│       ├── message.dart
│       ├── contact.dart
│       ├── call.dart
│       ├── user_profile.dart
│       ├── status.dart
│       └── database_generated.dart          # Generated Supabase types
│
├── assets/
│   ├── images/
│   ├── icons/
│   └── animations/                          # Lottie/Rive animations
│
├── android/
├── ios/
├── test/
├── integration_test/
│
├── pubspec.yaml
├── analysis_options.yaml
├── build.yaml                               # Build runner config
├── l10n.yaml                                # Localization config
├── .env
├── .env.example
└── README.md
```

---

## 3. PHASE 1: FOUNDATION (Weeks 1-3)

### 3.1 Project Initialization

```bash
# Create Flutter project
flutter create crystal_messenger --org com.crystalmessenger --platforms android,ios

# Core dependencies
flutter pub add \
  flutter_riverpod riverpod_annotation \
  go_router \
  supabase_flutter \
  drift sqlite3_flutter_libs \
  flutter_secure_storage \
  connectivity_plus \
  path_provider \
  dio \
  cached_network_image \
  flutter_svg \
  qr_flutter \
  intl \
  formz \
  uuid \
  freezed_annotation \
  json_annotation \
  image_picker \
  camera \
  flutter_contacts \
  just_audio record \
  video_player chewie \
  flutter_local_notifications \
  firebase_core firebase_messaging \
  workmanager \
  flutter_haptic_feedback \
  permission_handler \
  share_plus \
  url_launcher \
  device_info_plus \
  package_info_plus

# Dev dependencies
flutter pub add --dev \
  build_runner freezed_annotation \
  json_serializable \
  drift_dev \
  riverpod_generator \
  mocktail \
  integration_test
```

### 3.2 Supabase Integration

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 2,
    ),
  );
  
  runApp(const ProviderScope(child: CrystalMessengerApp()));
}
```

### 3.3 Database Schema (Same Supabase Backend)

**NO database changes needed.** The existing Supabase schema with 20 tables, 14 RPCs, and RLS policies works identically with Flutter. The `supabase_flutter` package uses the same PostgREST API.

### 3.4 Type Generation

```dart
// Use Supabase CLI to generate Dart types
// supabase gen types dart --project-id YOUR_PROJECT_ID > lib/models/database_generated.dart
```

### 3.5 Theme System

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  static const primary = Color(0xFF00A884);
  static const primaryLight = Color(0x2200A884);
  static const primaryDark = Color(0xFF008069);
  static const secondary = Color(0xFF53BDEB);
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const surfaceVariant = Color(0xFF1A1A1A);
  static const chatBubbleOutgoing = Color(0xFF005C4B);
  static const chatBubbleIncoming = Color(0xFF1A1A1A);
  static const onlineIndicator = Color(0xFF25D366);
  // ... all colors from React Native theme
}

// lib/core/theme/app_theme.dart
class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
    ),
    // ... complete theme
  );
}
```

### 3.6 Riverpod Architecture

**Zustand Store → Riverpod Provider mapping:**

| Zustand Store | Riverpod Provider | Type |
|---|---|---|
| `useAuthStore` | `authProvider` | `AsyncNotifierProvider<AuthNotifier, AuthState>` |
| `useUIStore` | `uiProvider` | `NotifierProvider<UiNotifier, UiState>` |
| `useChatStore` | `chatProvider` | `NotifierProvider<ChatNotifier, ChatState>` |
| `useNetworkStore` | `networkProvider` | `StreamProvider<ConnectivityResult>` |
| `useSettingsStore` | `settingsProvider` | `NotifierProvider<SettingsNotifier, SettingsState>` |
| `useNotificationStore` | `notificationProvider` | `NotifierProvider<NotificationNotifier, NotificationState>` |
| `useMediaStore` | `mediaCacheProvider` | `NotifierProvider<MediaCacheNotifier, MediaCacheState>` |
| `useConnectionStore` | `connectionProvider` | `NotifierProvider<ConnectionNotifier, ConnectionState>` |
| `useChatPrefsStore` | `chatPrefsProvider` | `NotifierProvider<ChatPrefsNotifier, ChatPrefsState>` |

### 3.7 Riverpod Auth Provider Example

```dart
// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    User? user,
    Session? session,
    @Default(false) bool isAuthenticated,
    @Default(true) bool isLoading,
    @Default(false) bool isOnboarded,
    @Default(false) bool isInitialized,
  }) = _AuthState;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Fast path: return cached state (WhatsApp-style offline boot)
    final cached = await _loadCachedAuth();
    if (cached != null) return cached;

    // Slow path: restore session from SecureStore
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session != null && user != null) {
      final profile = await _fetchProfile(user.id);
      return AuthState(
        user: profile,
        session: session,
        isAuthenticated: true,
        isOnboarded: profile?.phone != null,
        isInitialized: true,
      );
    }

    return const AuthState(isInitialized: true);
  }

  Future<void> signInAnonymously() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await Supabase.instance.client.auth.signInAnonymously();
      return AuthState(
        user: null,
        session: response.session,
        isAuthenticated: true,
        isOnboarded: false,
        isInitialized: true,
      );
    });
  }

  Future<void> completeOnboarding({
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    state = await AsyncValue.guard(() async {
      final user = state.value!.user;
      // Upsert profile with phone/name
      // If phone held by stale anonymous, claim_phone RPC frees it
      final profile = await _upsertProfile(
        userId: user!.id,
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
      );
      return state.value!.copyWith(
        user: profile,
        isOnboarded: true,
      );
    });
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    ref.invalidateSelf();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// Derived providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.isAuthenticated ?? false;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull?.user;
});
```

### 3.8 GoRouter Navigation

```dart
// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/onboarding_screen.dart';
import '../features/auth/presentation/screens/permissions_screen.dart';
import '../features/chat/presentation/screens/chat_list_screen.dart';
import '../features/chat/presentation/screens/chat_detail_screen.dart';
import '../features/contacts/presentation/screens/contacts_screen.dart';
import '../features/calls/presentation/screens/call_history_screen.dart';
import '../features/calls/presentation/screens/call_screen.dart';
import '../features/status/presentation/screens/updates_screen.dart';
import '../features/status/presentation/screens/status_compose_screen.dart';
import '../features/status/presentation/screens/status_viewer_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/qr_code/presentation/screens/qr_code_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isInitialized = authState.valueOrNull?.isInitialized ?? false;
      final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
      final isOnboarded = authState.valueOrNull?.isOnboarded ?? false;

      if (!isInitialized) return '/splash';
      if (!isAuthenticated) return '/onboarding';
      if (!isOnboarded) return '/onboarding';
      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/permissions', builder: (_, __) => const PermissionsScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/updates', builder: (_, __) => const UpdatesScreen()),
          GoRoute(path: '/calls', builder: (_, __) => const CallHistoryScreen()),
          GoRoute(path: '/communities', builder: (_, __) => const CommunitiesPlaceholder()),
        ],
      ),
      GoRoute(path: '/chat/:id', builder: (_, state) => ChatDetailScreen(chatId: state.pathParameters['id']!)),
      GoRoute(path: '/contacts', builder: (_, __) => const ContactsScreen()),
      GoRoute(path: '/contacts/:id', builder: (_, state) => ContactDetailScreen(contactId: state.pathParameters['id']!)),
      GoRoute(path: '/new-contact', builder: (_, __) => const NewContactScreen()),
      GoRoute(path: '/call/:id', builder: (_, state) => CallScreen(callId: state.pathParameters['id']!)),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/qr-code', builder: (_, __) => const QrCodeScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/status/compose', builder: (_, __) => const StatusComposeScreen()),
      GoRoute(path: '/status/:id', builder: (_, state) => StatusViewerScreen(statusId: state.pathParameters['id']!)),
    ],
  );
});
```

### 3.9 Offline Database (Drift)

```dart
// lib/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get createdBy => text().nullable()();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  IntColumn get disappearingTimer => integer().withDefault(const Constant(0))();
  TextColumn get lastMessageContent => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text().references(Chats, #id)();
  TextColumn get senderId => text()();
  TextColumn get content => text().nullable()();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  TextColumn get replyToId => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get displayName => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [Chats, Messages, Contacts, PendingActions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Chat DAO methods
  Future<List<Chat>> getAllChats() => (select(chats)
    ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)]))
    .get();

  Stream<List<Chat>> watchAllChats() => (select(chats)
    ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)]))
    .watch();

  Future<void> upsertChat(Chat chat) => into(chats).insertOnConflictUpdate(chat);

  // Message DAO methods
  Future<List<Message>> getMessagesForChat(String chatId, {int limit = 50}) =>
      (select(messages)
        ..where((t) => t.chatId.equals(chatId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit))
      .get();

  Stream<List<Message>> watchMessagesForChat(String chatId) =>
      (select(messages)
        ..where((t) => t.chatId.equals(chatId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<void> insertMessage(Message message) => into(messages).insert(message);

  // Pending actions (offline queue)
  Future<void> addPendingAction(String type, String payload) =>
      into(pendingActions).insert(PendingActionsCompanion.insert(
        actionType: type,
        payload: payload,
        createdAt: DateTime.now(),
      ));

  Future<List<PendingAction>> getPendingActions() => select(pendingActions).get();

  Future<void> removePendingAction(int id) =>
      (delete(pendingActions)..where((t) => t.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'crystal_messenger', 'crystal.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

---

## 4. PHASE 2: CORE FEATURES (Weeks 4-8)

### 4.1 Chat System (Same as React Native)

**Features to replicate:**
- Real-time 1:1 messaging via CrystalSocket + Supabase Realtime fallback
- Optimistic sends with reconciliation
- Offline queue (PendingActions table)
- Typing indicators
- Delivery receipts (single ✓)
- Read receipts (double ✓✓)
- Reply to messages (`reply_to_id`)
- Delete for everyone
- Clear chat
- 24h disappearing messages

**CrystalSocket (Erlang WebSocket) — Same server, new client:**

```dart
// lib/services/realtime/crystal_socket.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrystalSocket {
  WebSocketChannel? _channel;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _userId;
  String? _jwt;
  
  final _eventController = StreamController<SocketEvent>.broadcast();
  Stream<SocketEvent> get events => _eventController.stream;

  void connect({required String userId, required String jwt}) {
    _userId = userId;
    _jwt = jwt;
    _connectToServer();
  }

  void _connectToServer() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://your-erlang-server.com/ws'),
    );

    // Auth frame (first frame must be auth)
    _channel!.sink.add(jsonEncode({
      'type': 'auth',
      'user_id': _userId,
      'jwt': _jwt,
    }));

    _channel!.stream.listen(
      _onMessage,
      onDone: _onDisconnected,
      onError: _onError,
    );

    _startHeartbeat();
    _reconnectAttempts = 0;
  }

  void _onMessage(dynamic data) {
    final event = SocketEvent.fromJson(jsonDecode(data));
    _eventController.add(event);
  }

  void _onDisconnected() {
    _stopHeartbeat();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, 30),
    );
    _reconnectTimer = Timer(delay, _connectToServer);
    _reconnectAttempts++;
  }

  void _startHeartbeat() {
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void sendTyping(String chatId) {
    _channel?.sink.add(jsonEncode({
      'type': 'typing',
      'chat_id': chatId,
      'user_id': _userId,
    }));
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode({
      'type': 'message',
      ...message,
    }));
  }

  void sendCallSignal(Map<String, dynamic> signal) {
    _channel?.sink.add(jsonEncode({
      'type': 'call_signal',
      ...signal,
    }));
  }

  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }
}
```

### 4.2 Message Repository

```dart
// lib/features/chat/data/repositories/message_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../database/app_database.dart';
import '../../../services/realtime/crystal_socket.dart';

class MessageRepository {
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final CrystalSocket _socket;

  MessageRepository(this._supabase, this._database, this._socket);

  // Send message (optimistic)
  Future<Message> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? replyToId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // 1. Insert locally (optimistic)
    final localMessage = MessagesCompanion.insert(
      id: _generateUuid(),
      chatId: chatId,
      senderId: userId,
      content: content,
      messageType: messageType,
      replyToId: Value(replyToId),
      createdAt: DateTime.now(),
    );
    await _database.into(_database.messages).insert(localMessage);

    // 2. Send via RPC
    final result = await _supabase.rpc('send_message', params: {
      'p_chat_id': chatId,
      'p_content': content,
      'p_message_type': messageType,
      'p_reply_to_id': replyToId,
    });

    // 3. Update local with server ID if different
    if (result != null && result['id'] != localMessage.id.value) {
      // Update local message with server-assigned ID
    }

    return localMessage;
  }

  // Watch messages for a chat (local-first)
  Stream<List<Message>> watchMessages(String chatId) {
    return _database.watchMessagesForChat(chatId);
  }

  // Subscribe to real-time messages
  void subscribeToMessages(String chatId, void Function(Message) onMessage) {
    _supabase
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) async {
            final message = Message.fromJson(payload.newRecord);
            await _database.into(_database.messages).insert(message);
            onMessage(message);
          },
        )
        .subscribe();
  }

  // Typing indicators via CrystalSocket
  void sendTypingIndicator(String chatId) {
    _socket.sendTyping(chatId);
  }

  // Mark messages as read
  Future<void> markAsRead(String chatId) async {
    await _supabase.rpc('mark_messages_read', params: {
      'p_chat_id': chatId,
    });
  }

  // Delete message for everyone
  Future<void> deleteForEveryone(String messageId) async {
    await _supabase.rpc('delete_message_for_everyone', params: {
      'p_message_id': messageId,
    });
  }
}
```

### 4.3 WebRTC Calls

```dart
// lib/services/rtc/web_rtc_session.dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcSession {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final _remoteRenderer = RTCVideoRenderer();

  Future<void> initialize() async {
    await _remoteRenderer.initialize();
  }

  Future<void> startCall({
    required String callerId,
    required String calleeId,
    required bool isVideo,
  }) async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });

    // Get local media
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    });

    // Add tracks
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle remote stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      }
    };

    // ICE candidate handling
    _peerConnection!.onIceCandidate = (candidate) {
      // Send to signaling server
    };

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    // Send offer via signaling
  }

  Future<void> answerCall({required bool isVideo}) async {
    // Similar to startCall but with answer
  }

  Future<void> toggleMute() async {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  Future<void> toggleCamera() async {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  Future<void> switchCamera() async {
    _localStream?.getVideoTracks().forEach((track) {
      // Switch facing mode
    });
  }

  Future<void> endCall() async {
    await _peerConnection?.close();
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    _remoteRenderer.dispose();
  }

  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
}
```

### 4.4 Voice Notes

```dart
// lib/services/audio/voice_recorder.dart
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _duration = Duration.zero;

  Future<bool> startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      
      _isRecording = true;
      return true;
    }
    return false;
  }

  Future<String?> stopRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _isRecording = false;
      return path;
    }
    return null;
  }

  bool get isRecording => _isRecording;
}
```

### 4.5 Media Upload/Download

```dart
// lib/services/media/media_uploader.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class MediaUploader {
  final SupabaseClient _supabase;

  MediaUploader(this._supabase);

  Future<String> uploadAvatar(File file) async {
    final userId = _supabase.auth.currentUser!.id;
    final ext = p.extension(file.path);
    final path = '$userId/avatar$ext';

    await _supabase.storage.from('avatars').upload(path, file, 
      fileOptions: const FileOptions(upsert: true),
    );

    return 'avatars/$path'; // Store bare reference, not URL
  }

  Future<String> uploadMedia(File file, {String? chatId}) async {
    final userId = _supabase.auth.currentUser!.id;
    final ext = p.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/media-$timestamp$ext';

    await _supabase.storage.from('media').upload(path, file);

    return 'media/$path'; // Store bare reference
  }

  Future<String> uploadVoiceNote(File file) async {
    final userId = _supabase.auth.currentUser!.id;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/voice-$timestamp.m4a';

    await _supabase.storage.from('media').upload(path, file);

    return 'media/$path';
  }
}

// lib/services/media/media_url_resolver.dart
import 'dart:collection';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaUrlResolver {
  final SupabaseClient _supabase;
  final LinkedHashMap<String, _CachedUrl> _cache = LinkedHashMap();

  MediaUrlResolver(this._supabase);

  Future<String> resolve(String reference) async {
    // Check memory cache
    final cached = _cache[reference];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Resolve to signed URL (1-hour TTL)
    final signedUrl = await _supabase.storage
        .from(reference.split('/').first)
        .createSignedUrl(
          reference.substring(reference.indexOf('/') + 1),
          const Duration(hours: 1),
        );

    // Cache with renewal
    _cache[reference] = _CachedUrl(
      url: signedUrl,
      expiresAt: DateTime.now().add(const Duration(minutes: 50)),
    );

    return signedUrl;
  }

  void clearCache() => _cache.clear();
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  _CachedUrl({required this.url, required this.expiresAt});
}
```

---

## 5. PHASE 3: ADVANCED FEATURES (Weeks 9-12)

### 5.1 Contact Sync

```dart
// lib/services/contacts/contact_sync_service.dart
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactSyncService {
  final SupabaseClient _supabase;

  ContactSyncService(this._supabase);

  Future<List<Map<String, dynamic>>> syncDeviceContacts() async {
    // Request permission
    if (!await FlutterContacts.requestPermission()) {
      return [];
    }

    // Get device contacts
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    // Extract phone numbers
    final phoneNumbers = deviceContacts
        .where((c) => c.phones.isNotEmpty)
        .map((c) => c.phones.first.number.replaceAll(RegExp(r'[^\d+]'), ''))
        .toList();

    // Match against Supabase profiles
    final matched = await _supabase.rpc('match_contacts', params: {
      'phone_numbers': phoneNumbers,
    });

    return matched;
  }
}
```

### 5.2 Push Notifications

```dart
// lib/services/push/push_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get token
      final token = await _messaging.getToken();
      await _registerToken(token!);

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_registerToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    }
  }

  Future<void> _registerToken(String token) async {
    await Supabase.instance.client.rpc('upsert_push_token', params: {
      'p_token': token,
      'p_platform': 'flutter',
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification
    _showLocalNotification(message);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    // Background sync (like Telegram-style catch-up)
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to relevant screen
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Show notification with proper channel
  }
}
```

### 5.3 Status Updates (Stories)

```dart
// lib/features/status/data/repositories/status_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class StatusRepository {
  final SupabaseClient _supabase;

  StatusRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getStatusFeed() async {
    final feed = await _supabase.rpc('get_status_feed');
    return List<Map<String, dynamic>>.from(feed);
  }

  Future<void> createTextStatus({
    required String content,
    String backgroundColor = '#000000',
    String textColor = '#ffffff',
  }) async {
    await _supabase.from('statuses').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'content': content,
      'media_type': 'text',
      'background_color': backgroundColor,
      'text_color': textColor,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  Future<void> createMediaStatus({
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    await _supabase.from('statuses').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  Future<void> recordView(String statusId) async {
    await _supabase.rpc('record_status_view', params: {
      'p_status_id': statusId,
    });
  }
}
```

### 5.4 Settings Persistence

```dart
// lib/features/settings/presentation/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'settings_provider.freezed.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default('system') String theme,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool messagePreview,
    @Default(true) bool soundEnabled,
    @Default(true) bool vibrationEnabled,
    @Default('wifi') String autoDownload,
    @Default(false) bool lowDataUsage,
    @Default(false) bool biometricLock,
    @Default(false) bool pinLock,
    @Default('') String pin,
    @Default('English') String language,
    @Default('aurora') String wallpaper,
    @Default(false) bool enterIsSend,
    @Default(true) bool readReceipts,
    @Default(true) bool onlineStatus,
    @Default(false) bool disappearingMessages,
  }) = _SettingsState;
}

class SettingsNotifier extends Notifier<SettingsState> {
  final _storage = const FlutterSecureStorage();

  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    final theme = await _storage.read(key: 'theme') ?? 'system';
    final notifications = await _storage.read(key: 'notifications') != 'false';
    // ... load all settings
    state = SettingsState(
      theme: theme,
      notificationsEnabled: notifications,
      // ...
    );
  }

  Future<void> _saveSetting(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
    _saveSetting('theme', theme);
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
    _saveSetting('notifications', enabled.toString());
  }

  // ... all other setters
}
```

---

## 6. PHASE 4: POLISH & DEPLOY (Weeks 13-16)

### 6.1 Animations

```dart
// Implicit animations (Flutter built-in)
AnimatedContainer(
  duration: Duration(milliseconds: 250),
  curve: Curves.easeInOut,
  // ...
)

// Hero animations for transitions
Hero(
  tag: 'chat-$chatId',
  child: ChatTile(chat: chat),
)

// Custom page transitions
GoRoute(
  pageBuilder: (context, state) => CustomTransitionPage(
    child: ChatDetailScreen(chatId: state.pathParameters['id']!),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        )),
        child: child,
      );
    },
  ),
)
```

### 6.2 Testing

```dart
// test/features/chat/message_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MessageRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockAppDatabase mockDatabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockDatabase = MockAppDatabase();
    repository = MessageRepository(mockSupabase, mockDatabase);
  });

  group('sendMessage', () {
    test('inserts message locally before server confirmation', () async {
      // Arrange
      when(() => mockDatabase.into(any())).thenReturn(any());
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) async => {'id': 'server-id'});

      // Act
      final message = await repository.sendMessage(
        chatId: 'chat-1',
        content: 'Hello',
      );

      // Assert
      expect(message.content, equals('Hello'));
      verify(() => mockDatabase.into(any())).called(1);
    });
  });
}
```

### 6.3 CI/CD Pipeline

```yaml
# codemagic.yaml (same as React Native, updated for Flutter)
workflows:
  production:
    name: Production Build
    environment:
      flutter: stable
    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Generate code
        script: dart run build_runner build --delete-conflicting-outputs
      - name: Run tests
        script: flutter test
      - name: Build Android
        script: flutter build appbundle --release
      - name: Build iOS
        script: flutter build ipa --release
    artifacts:
      - build/**/outputs/**/*.aab
      - build/ios/ipa/*.ipa
```

---

## 7. STATE MANAGEMENT MIGRATION DETAILS

### Zustand → Riverpod Complete Mapping

```dart
// === AUTH STATE ===
// Zustand: useAuthStore with persist middleware
// Riverpod: AsyncNotifier with Hive/SharedPreferences persistence

// === UI STATE ===
// Zustand: useUIStore with persist middleware
// Riverpod: Notifier with SharedPreferences persistence

// === CHAT STATE ===
// Zustand: useChatStore (in-memory only)
// Riverpod: Notifier (in-memory only)

// === NETWORK STATE ===
// Zustand: useNetworkStore (in-memory)
// Riverpod: StreamProvider<ConnectivityResult>

// === SETTINGS STATE ===
// Zustand: useSettingsStore with persist middleware
// Riverpod: Notifier with SecureStorage persistence

// === NOTIFICATION STATE ===
// Zustand: useNotificationStore with persist middleware
// Riverpod: Notifier with SecureStorage persistence

// === MEDIA CACHE ===
// Zustand: useMediaStore (in-memory Map)
// Riverpod: Notifier (in-memory Map)

// === CONNECTION STATE ===
// Zustand: useConnectionStore (in-memory)
// Riverpod: Notifier (in-memory)

// === CHAT PREFS ===
// Zustand: useChatPrefsStore with persist middleware
// Riverpod: Notifier with SharedPreferences persistence
```

### Provider Dependency Graph

```
supabaseProvider
    ├── authProvider
    ├── chatListProvider
    ├── chatDetailProvider
    ├── messageProvider
    ├── contactsProvider
    ├── callProvider
    ├── statusProvider
    └── profileProvider

databaseProvider
    ├── chatLocalSource
    ├── messageLocalSource
    └── contactLocalSource

crystalSocketProvider
    ├── typingProvider
    ├── callSignalingProvider
    └── presenceProvider

networkProvider
    ├── connectionProvider
    └── offlineQueueProvider

sharedPreferencesProvider
    ├── settingsProvider
    ├── chatPrefsProvider
    └── notificationProvider
```

---

## 8. BACKEND & DEPLOYMENT

### 8.1 Backend (NO Changes)

The entire Supabase backend remains unchanged:
- **Database**: 20 tables, RLS policies, RPCs
- **Auth**: Anonymous sign-in, phone identity
- **Storage**: media + avatars buckets
- **Realtime**: postgres_changes subscriptions
- **Edge Functions**: send-message-push

The Erlang real-time server also remains unchanged — only the client library changes.

### 8.2 Deployment Strategy

| Component | Deployment | Notes |
|---|---|---|
| Supabase | Existing project | No changes |
| Erlang Server | Docker on existing host | No changes |
| Flutter App | App Store / Google Play | New build |
| OTA Updates | Not available in Flutter | Use Play Store / App Store rollouts |

### 8.3 Seamless Update Strategy

**Flutter does NOT support OTA updates like Expo.** Instead:

1. **Play Store In-App Updates API** — Prompt users for updates
2. **Feature Flags via Supabase** — Toggle features server-side
3. **Progressive Rollout** — 10% → 50% → 100% on Play Store
4. **iOS TestFlight** — Beta testing before production

```dart
// lib/services/update/update_service.dart
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  Future<void> checkForUpdates() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // Silently fail — don't block app usage
    }
  }
}
```

---

## 9. MIGRATION TIMELINE

| Phase | Duration | Deliverables |
|---|---|---|
| **Phase 1** | Weeks 1-3 | Project setup, Supabase integration, Auth flow, Navigation, Theme, Offline DB |
| **Phase 2** | Weeks 4-8 | Chat system, Messaging, Calls, Voice notes, Media, Contacts, Typing indicators |
| **Phase 3** | Weeks 9-12 | Status updates, Settings, Push notifications, QR code, Profile, Presence |
| **Phase 4** | Weeks 13-16 | Animations, Polish, Testing, CI/CD, Store submission |

**Total: 16 weeks (4 months)**

---

## 10. KEY ARCHITECTURAL DECISIONS

1. **Same Supabase backend** — Zero database migration, zero data loss
2. **Same Erlang server** — WebSocket protocol unchanged
3. **Riverpod over BLoC** — More flexible, testable, and closer to Zustand's mental model
4. **Drift over sqflite** — Type-safe SQLite with compile-time query validation
5. **Freezed for models** — Immutable data classes with pattern matching
6. **GoRouter over auto_route** — Official, well-maintained, deep linking support
7. **Feature-first architecture** — Same clean separation as React Native version
8. **No OTA updates** — Use Play Store/App Store progressive rollouts instead

---

## 11. PACKAGE VERSIONS (pubspec.yaml)

```yaml
name: crystal_messenger
description: Crystal Messenger - WhatsApp Clone
version: 1.3.0+1
publish_to: 'none'

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  
  # Navigation
  go_router: ^14.2.0
  
  # Supabase
  supabase_flutter: ^2.5.0
  
  # Database
  drift: ^2.16.0
  sqlite3_flutter_libs: ^0.5.20
  
  # Storage
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.2.2
  path_provider: ^2.1.2
  
  # Network
  dio: ^5.4.1
  connectivity_plus: ^6.0.3
  web_socket_channel: ^2.4.0
  
  # Media
  image_picker: ^1.0.7
  camera: ^0.10.5+9
  cached_network_image: ^3.3.1
  flutter_svg: ^2.0.9+1
  video_player: ^2.8.6
  chewie: ^1.8.1
  
  # Audio
  just_audio: ^0.9.36
  record: ^5.0.4
  
  # Contacts
  flutter_contacts: ^1.1.7+1
  
  # WebRTC
  flutter_webrtc: ^0.9.48
  
  # Push Notifications
  firebase_core: ^2.27.1
  firebase_messaging: ^14.7.15
  flutter_local_notifications: ^17.2.4
  
  # Background Tasks
  workmanager: ^0.5.2
  
  # QR Code
  qr_flutter: ^4.1.0
  
  # Forms
  formz: ^0.7.0
  
  # Utils
  uuid: ^4.3.3
  intl: ^0.19.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  url_launcher: ^6.2.4
  share_plus: ^7.2.1
  device_info_plus: ^10.1.0
  package_info_plus: ^8.1.0
  flutter_haptic_feedback: ^2.0.1
  permission_handler: ^11.3.0
  in_app_update: ^4.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.8
  freezed_annotation: ^2.4.1
  json_serializable: ^6.7.1
  drift_dev: ^2.16.0
  riverpod_generator: ^2.4.0
  mocktail: ^1.0.3

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
    - assets/animations/
```

---

## SUMMARY

This plan provides a **complete, production-ready migration** from React Native to Flutter with:

- **Zero backend changes** — Supabase + Erlang server untouched
- **Same feature set** — Chat, calls, media, contacts, status, settings
- **Same UX patterns** — Optimistic UI, offline-first, triple fallback realtime
- **Clean architecture** — Feature-first with Riverpod, Drift, GoRouter
- **Scalable** — Provider dependency graph, type-safe models, testable
- **Seamless updates** — Play Store in-app updates + feature flags

The migration preserves the existing codebase as reference while building a native Flutter app that's faster, more maintainable, and ready for production.
