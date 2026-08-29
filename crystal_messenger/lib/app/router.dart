import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/onboarding_screen.dart';
import '../features/auth/presentation/screens/permissions_screen.dart';
import '../features/chat/presentation/screens/chat_list_screen.dart';
import '../features/chat/presentation/screens/chat_detail_screen.dart';
import '../features/chat/presentation/screens/create_group_screen.dart';
import '../features/chat/presentation/screens/chat_info_screen.dart';
import '../features/chat/presentation/screens/chat_search_screen.dart';
import '../features/chat/presentation/screens/archived_chats_screen.dart';
import '../features/chat/presentation/screens/starred_messages_screen.dart';
import '../features/chat/presentation/screens/new_broadcast_screen.dart';
import '../features/contacts/presentation/screens/contacts_screen.dart';
import '../features/contacts/presentation/screens/contact_detail_screen.dart';
import '../features/contacts/presentation/screens/new_contact_screen.dart';
import '../features/calls/presentation/screens/call_history_screen.dart';
import '../features/calls/presentation/screens/call_screen.dart';
import '../features/status/presentation/screens/updates_screen.dart';
import '../features/status/presentation/screens/status_compose_screen.dart';
import '../features/status/presentation/screens/status_viewer_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/account_screen.dart';
import '../features/settings/presentation/screens/privacy_screen.dart';
import '../features/settings/presentation/screens/appearance_screen.dart';
import '../features/settings/presentation/screens/notification_settings_screen.dart';
import '../features/settings/presentation/screens/chats_screen.dart';
import '../features/settings/presentation/screens/data_storage_screen.dart';
import '../features/qr_code/presentation/screens/qr_code_screen.dart';
import '../features/shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isInitialized = authState.isInitialized;
      final isAuthenticated = authState.isAuthenticated;
      final isOnboarded = authState.isOnboarded;
      final location = state.matchedLocation;

      // Still loading
      if (!isInitialized && authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      // Not authenticated
      if (!isAuthenticated) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // Authenticated but not onboarded
      if (!isOnboarded) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // Authenticated + onboarded, redirect away from auth screens
      if (location == '/splash' || location == '/onboarding') {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatListScreen(),
            ),
          ),
          GoRoute(
            path: '/updates',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UpdatesScreen(),
            ),
          ),
          GoRoute(
            path: '/calls',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CallHistoryScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:chatId',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ChatDetailScreen(chatId: state.pathParameters['chatId']!),
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
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/contacts/:contactId',
        builder: (context, state) => ContactDetailScreen(
          contactId: state.pathParameters['contactId']!,
        ),
      ),
      GoRoute(
        path: '/new-contact',
        builder: (context, state) => const NewContactScreen(),
      ),
      GoRoute(
        path: '/new-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/new-broadcast',
        builder: (context, state) => const NewBroadcastScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId/info',
        builder: (context, state) => ChatInfoScreen(
          chatId: state.pathParameters['chatId']!,
        ),
      ),
      GoRoute(
        path: '/chat/:chatId/search',
        builder: (context, state) => ChatSearchScreen(
          chatId: state.pathParameters['chatId']!,
        ),
      ),
      GoRoute(
        path: '/archived',
        builder: (context, state) => const ArchivedChatsScreen(),
      ),
      GoRoute(
        path: '/starred',
        builder: (context, state) => const StarredMessagesScreen(),
      ),
      GoRoute(
        path: '/call/:callId',
        builder: (context, state) => CallScreen(
          callId: state.pathParameters['callId']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/qr-code',
        builder: (context, state) => const QrCodeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/chats',
        builder: (context, state) => const ChatsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        builder: (context, state) => const DataStorageScreen(),
      ),
      GoRoute(
        path: '/status/compose',
        builder: (context, state) => const StatusComposeScreen(),
      ),
      GoRoute(
        path: '/status/:statusId',
        builder: (context, state) => StatusViewerScreen(
          statusId: state.pathParameters['statusId']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.matchedLocation}')),
    ),
  );
});
