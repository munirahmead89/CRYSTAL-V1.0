import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/app_lock_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/restore_profile_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/auth/presentation/pages/setup_profile_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../core/connectivity/connectivity_providers.dart';
import '../core/security/app_lock.dart';
import '../core/storage/app_preferences.dart';
import '../features/ban/presentation/pages/banned_page.dart';
import '../features/conversations/presentation/pages/chat_page.dart';
import '../features/conversations/presentation/pages/contact_info_page.dart';
import '../features/conversations/presentation/pages/group_create_page.dart';
import '../features/conversations/presentation/pages/people_page.dart';
import '../features/conversations/presentation/pages/qr_scanner_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/profile/presentation/pages/link_device_page.dart';
import '../features/profile/presentation/pages/qr_code_page.dart';
import '../features/profile/presentation/pages/qr_hub_page.dart';
import '../features/profile/presentation/pages/settings_page.dart';
import '../features/profile/presentation/pages/sub_settings_pages.dart';
import '../features/profile/presentation/pages/settings_sub_pages_extra.dart';
import '../shared/models/conversation.dart';
import '../shared/models/user_profile.dart';

/// Central route-name registry so navigation never uses raw strings.
abstract final class Routes {
  static const home = 'home';
  static const welcome = 'welcome';
  static const login = 'login';
  static const signup = 'signup';
  static const setup = 'setup';
  static const restore = 'restore';
  static const people = 'people';
  static const chat = 'chat';
  static const qr = 'qr';
  static const qrHub = 'qr-hub';
  static const linkDevice = 'link-device';
  static const scan = 'scan';
  static const group = 'group';
  static const settings = 'settings';
  static const banned = 'banned';
  static const accountSettings = 'account-settings';
  static const lock = 'lock';
  static const privacySettings = 'privacy-settings';
  static const notificationsSettings = 'notifications-settings';
  static const chatsSettings = 'chats-settings';
  static const storageSettings = 'storage-settings';
  static const helpSettings = 'help-settings';
  static const contact = 'contact';
  static const accountTwoStep = 'account-two-step';
  static const accountDevices = 'account-devices';
  static const storageManage = 'storage-manage';
  static const storageNetwork = 'storage-network';
}

/// The application-wide navigator, exposed so background handlers can push a
/// screen from anywhere (deep settings, chat thread, tabs) without needing a
/// BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(ownProfileProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  void trackRoute(String route) {
    // Don't track onboarding routes
    if (route == '/welcome' ||
        route == '/login' ||
        route == '/signup' ||
        route == '/restore' ||
        route == '/setup') {
      return;
    }
    _ref
        .read(appPreferencesProvider.future)
        .then((prefs) => prefs.setLastRoute(route))
        .ignore();
  }
}

GoRouter createRouter(Ref ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigatorKey,
    refreshListenable: notifier,
    redirect: (context, state) {
      notifier.trackRoute(state.matchedLocation);
      return _redirect(ref, state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: '/',
        name: Routes.home,
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'people',
            name: Routes.people,
            builder: (context, state) => const PeoplePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/lock',
        name: Routes.lock,
        builder: (context, state) => AppLockPage(
          onUnlocked: () {
            // Replace rather than go(), so Back cannot return to the lock and
            // trapping the user on it.
            context.go('/');
          },
        ),
      ),
      GoRoute(
        path: '/welcome',
        name: Routes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      // Email sign-in and sign-up. These two pages existed and were reachable
      // from `login_page`/`welcome_page` via `context.push('/login')`, but no
      // GoRoute was ever registered for either path, so every entry point
      // threw "no routes for location". Registering them is what makes
      // `linkGuestAccount`, device-link sign-in and a returning email user
      // reachable at all.
      GoRoute(
        path: '/login',
        name: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        name: Routes.signup,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/restore',
        name: Routes.restore,
        builder: (context, state) => const RestoreProfilePage(),
      ),
      GoRoute(
        path: '/setup',
        name: Routes.setup,
        builder: (context, state) => const SetupProfilePage(),
      ),
      GoRoute(
        path: '/qr',
        name: Routes.qr,
        builder: (context, state) => const QrCodePage(),
      ),
      GoRoute(
        path: '/qr-hub',
        name: Routes.qrHub,
        builder: (context, state) => const QrHubPage(),
      ),
      GoRoute(
        path: '/link-device',
        name: Routes.linkDevice,
        builder: (context, state) => const LinkDevicePage(),
      ),
      GoRoute(
        path: '/scan',
        name: Routes.scan,
        builder: (context, state) => const QrScannerPage(),
      ),
      GoRoute(
        path: '/settings',
        name: Routes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/banned',
        name: Routes.banned,
        builder: (context, state) => const BannedPage(),
      ),
      GoRoute(
        path: '/group',
        name: Routes.group,
        builder: (context, state) => const GroupCreatePage(),
      ),
      GoRoute(
        path: '/chat/:id',
        name: Routes.chat,
        builder: (context, state) {
          final extra = state.extra;
          return ChatPage(
            conversationId: state.pathParameters['id']!,
            initialPeer: extra is ConversationSummary ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/contact',
        name: Routes.contact,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! UserProfile) {
            return const SizedBox.shrink();
          }
          return ContactInfoPage(profile: extra);
        },
      ),
      GoRoute(
        path: '/settings/account',
        name: Routes.accountSettings,
        builder: (context, state) => const AccountSettingsPage(),
        routes: [
          GoRoute(
            path: 'two-step',
            name: 'account-two-step',
            builder: (context, state) => const TwoStepVerificationPage(),
          ),
          GoRoute(
            path: 'devices',
            name: 'account-devices',
            builder: (context, state) => const LinkedDevicesPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/privacy',
        name: Routes.privacySettings,
        builder: (context, state) => const PrivacySettingsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        name: Routes.notificationsSettings,
        builder: (context, state) => const NotificationsSettingsPage(),
      ),
      GoRoute(
        path: '/settings/chats',
        name: Routes.chatsSettings,
        builder: (context, state) => const ChatsSettingsPage(),
      ),
      GoRoute(
        path: '/settings/storage',
        name: Routes.storageSettings,
        builder: (context, state) => const StorageDataSettingsPage(),
        routes: [
          GoRoute(
            path: 'manage',
            name: 'storage-manage',
            builder: (context, state) => const ManageStoragePage(),
          ),
          GoRoute(
            path: 'network',
            name: 'storage-network',
            builder: (context, state) => const NetworkUsagePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/help',
        name: Routes.helpSettings,
        builder: (context, state) => const HelpSettingsPage(),
      ),
    ],
  );
}

/// Routes that must stay reachable while the app lock is engaged.
///
/// Without this a user who locks themselves out has no path to Settings, and
/// therefore no way to turn the lock off.
bool _isOnboardingPath(String path) =>
    path == '/welcome' ||
    path == '/setup' ||
    path == '/restore' ||
    path == '/login' ||
    path == '/signup';

String? _redirect(Ref ref, String path) {
  final auth = ref.read(authStateProvider);

  // The lock screen and onboarding must stay reachable no matter what, or a
  // locked-out user would have no way out.
  if (path == '/lock') return null;

  // Cold start: a persisted session is still being recovered by gotrue. Hold
  // the current location and never bounce to onboarding — the restore event
  // (signed in) or the storage check (signed out) settles this in moments.
  if (auth.restoring) return null;

  // Signed out → onboarding, unless already there (or on an auth sub-flow
  // that produces a session: login, signup and the phone-based restore must
  // stay reachable so a user who was re-onboarded by an update can get back
  // in). `isSignedIn` is synchronous, so a redirect can never fire from a
  // transient stream value.
  if (!auth.isSignedIn) {
    if (path == '/welcome' ||
        path == '/login' ||
        path == '/signup' ||
        path == '/restore') {
      return null;
    }
    return '/welcome';
  }

  // App Lock. Checked AFTER sign-in but BEFORE anything else, because the whole
  // point is that no chat, media or profile is reachable until the user
  // unlocks. Without this the lock was a prompt layered over fully-rendered
  // content, which is what made it bypassable.
  //
  // Onboarding routes stay reachable: a user who has locked themselves out of
  // the app must still be able to get to settings and turn the lock off.
  if (path != '/lock' && !_isOnboardingPath(path)) {
    final lock = ref.read(appLockControllerProvider);
    if (lock.isLocked) return '/lock';
  }

  // Offline / unknown connectivity: never bounce a signed-in user out of the
  // shell. Profile-fetch failures, realtime drops and token-refresh hiccups on
  // this path must not redirect to onboarding or setup — they are not
  // identity changes.
  final online = ref.read(isOnlineProvider).valueOrNull;
  if (online == false) {
    return (path == '/welcome' || path == '/setup' || path == '/restore')
        ? '/'
        : null;
  }

  // Online: ALL users must complete profile (name + phone) before accessing
  // the app. The profile is required for identity, restore, and QR features.
  final profileAsync = ref.read(ownProfileProvider);
  if (profileAsync.hasValue) {
    final profile = profileAsync.value!;
    final needsProfile =
        profile.displayName.trim().isEmpty || profile.phone.trim().isEmpty;
    if (needsProfile) {
      return (path == '/setup' || path == '/restore') ? null : '/setup';
    }
  } else if (profileAsync.isLoading) {
    return null; // Wait for profile
  } else if (profileAsync.hasError) {
    if (_isConnectivityError(profileAsync.error)) return null;
    return (path == '/setup' || path == '/restore') ? null : '/setup';
  }

  if (path == '/welcome' ||
      path == '/setup' ||
      path == '/login' ||
      path == '/signup') {
    return '/';
  }

  return null;
}

/// Rough, cross-platform check used only for redirect decisions — if a
/// profile fetch failed because of the network, the user must not be sent to
/// the setup flow (they were already set up).
bool _isConnectivityError(Object? error) {
  final text = '${error.runtimeType} $error'.toLowerCase();
  return text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('clientexception') ||
      text.contains('failed to fetch') ||
      text.contains('network is unreachable') ||
      text.contains('connection reset');
}
