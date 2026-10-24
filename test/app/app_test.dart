import 'dart:async';
import '../support/fake_relay_repository.dart';
import '../support/noop_relay_store.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crystal_messenger/app/app.dart';
import 'package:crystal_messenger/core/config/app_config.dart';
import 'package:crystal_messenger/core/config/app_config_provider.dart';
import 'package:crystal_messenger/core/config/environment.dart';
import 'package:crystal_messenger/core/connectivity/connectivity_providers.dart';
import 'package:crystal_messenger/core/connectivity/connectivity_service.dart';
import 'package:crystal_messenger/core/database/database.dart';
import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/features/auth/domain/entities/app_user.dart';
import 'package:crystal_messenger/features/auth/domain/repositories/auth_repository.dart';
import 'package:crystal_messenger/features/auth/presentation/pages/setup_profile_page.dart';
import 'package:crystal_messenger/features/auth/presentation/providers/auth_providers.dart';
import 'package:crystal_messenger/features/conversations/domain/repositories/chat_repositories.dart';
import 'package:crystal_messenger/features/conversations/presentation/providers/chat_providers.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:crystal_messenger/shared/models/conversation.dart';
import 'package:crystal_messenger/shared/models/user_profile.dart';
import 'package:crystal_messenger/shared/widgets/offline_banner.dart';
import 'package:drift/drift.dart'
    as drift
    show Column, InsertStatement, Insertable, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testConfig = AppConfig(
  environment: AppEnvironment.development,
  appName: 'Crystal Messenger',
  apiBaseUrl: '',
  supabaseUrl: '',
  supabaseAnonKey: '',
  logVerbosity: 'off',
);

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final _controller = StreamController<bool>.broadcast();
  final _rawController = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<bool> onConnectionChanged() {
    return Stream<bool>.multi((controller) {
      controller.add(online);
      final sub = _controller.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<List<ConnectivityResult>> onConnectivityChanged() {
    return Stream<List<ConnectivityResult>>.multi((controller) {
      controller.add(
        online ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
      );
      final sub = _rawController.stream.listen(
        (results) => controller.add(results),
      );
      controller.onCancel = sub.cancel;
    });
  }

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
    _rawController.add(
      value ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, UserProfile? profile})
    : profile =
          profile ??
          UserProfile(
            id: user?.id ?? 'me',
            displayName: 'Me',
            phone: '+15550001001',
          );

  final AppUser? user;

  /// Mutable so a test can start from an incomplete profile and observe the
  /// save-then-navigate behaviour of the onboarding form.
  UserProfile profile;

  /// Set when [fetchOwnProfile] should fail, to model a database whose schema
  /// is missing the columns the profile query embeds.
  bool failProfileFetch = false;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(user);

  @override
  AppUser? get currentUser => user;

  @override
  Future<AuthResult> signInAnonymously() async => const AuthSuccess();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async => const AuthSuccess();

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => const AuthSuccess();

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> linkGuestAccount({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<bool> refreshSessionIfAlive() async => user != null;

  @override
  Future<bool> hasPersistedSession() async => user != null;

  @override
  Future<UserProfile> fetchOwnProfile() async {
    if (failProfileFetch) {
      throw StateError('column devices.device_model does not exist');
    }
    return profile;
  }

  @override
  Future<void> updateOwnProfile({
    String? displayName,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    // Mirror the real repository so the provider holds what was written.
    profile = profile.copyWith(
      displayName: displayName ?? profile.displayName,
      phone: phone ?? profile.phone,
    );
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String deviceName,
    String? pushToken,
    String? appVersion,
    String? deviceIp,
    String? deviceLocale,
    String? deviceManufacturer,
    String? deviceModel,
    String? deviceOs,
  }) async {}

  @override
  Future<String?> deleteAccount() async => null;

  @override
  Future<void> updatePresence(String status) async {}
}

/// Simulates a cold start with a persisted session: gotrue has NOT restored it
/// synchronously (`currentUser` is null, `authStateChanges` first emits the
/// null INITIAL_SESSION event), but encrypted local storage proves a session
/// exists and it lands a moment later. The app must hold position and NEVER
/// flash onboarding during this window.
class RestoringAuthRepository extends FakeAuthRepository {
  RestoringAuthRepository({required this.deliveredUser}) : super(user: null);

  final AppUser deliveredUser;

  @override
  AppUser? get currentUser => null;

  @override
  Future<bool> hasPersistedSession() async => true;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield null;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    yield deliveredUser;
  }
}

class FakeConversationsRepository implements ConversationsRepository {
  @override
  Future<String> getOrCreateDirectConversation({
    required String peerId,
  }) async => 'conv-1';

  @override
  Future<ConversationSummary> createGroup({
    required String name,
    required List<String> memberIds,
  }) async => ConversationSummary(
    id: 'conv-1',
    isGroup: true,
    displayName: name,
    lastMessageType: 'text',
  );

  @override
  Future<List<ConversationSummary>> getChats() async => const [];

  @override
  Future<void> markChatRead({
    required String conversationId,
    String? upToMessageId,
  }) async {}

  @override
  Future<int> deleteConversationMessages(String conversationId) async => 0;

  @override
  Future<void> setDisappearingMessages(
    String conversationId,
    int seconds,
  ) async {}

  @override
  Future<int> getDisappearingSeconds(String conversationId) async => 0;

  @override
  Future<void> markDelivered(List<String> messageIds) async {}
}

class FakeMessagesRepository implements MessagesRepository {
  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async => const [];

  @override
  Future<List<ChatMessage>> getMessagesAfter(
    String conversationId, {
    required String? afterId,
    int limit = 100,
  }) async => const [];

  @override
  Future<ChatMessage> send(ChatMessage draft) async => draft;

  @override
  Future<List<MessageReaction>> setReaction({
    required String messageId,
    String? emoji,
  }) async => const [];

  /// Edits requested by the chat screen, so a test can assert that an edit was
  /// actually pushed rather than only that the local row changed.
  final edits = <({String messageId, String body})>[];

  @override
  Future<void> editText({
    required String messageId,
    required String body,
  }) async {
    edits.add((messageId: messageId, body: body));
  }
}

class FakePeopleRepository implements PeopleRepository {
  @override
  Future<UserProfile?> fetchProfileById(String id) async => null;

  @override
  Future<UserProfile?> fetchProfileByPhone(String phone) async => null;

  @override
  Future<UserProfile?> restoreProfileByPhone(String phone) async => null;

  @override
  Future<List<UserProfile>> searchProfiles(String query) async => const [];
}

class FakeLocalStore with NoopRelayStore implements LocalStore {
  @override
  Future<List<({String conversationId, int bytes, int fileCount})>>
  mediaBytesByConversation() async => const [];

  @override
  Future<({Set<String> fileNames, Map<String, int> referenceCounts})>
  mediaFilesForConversation(String conversationId) async =>
      (fileNames: <String>{}, referenceCounts: <String, int>{});

  @override
  Future<List<ChatMessage>> appLocalMessages({int limit = 500}) async =>
      const [];

  @override
  Future<List<UserProfile>> cacheProfileByPhone(String phone) async => const [];

  @override
  Future<List<ChatMessage>> cachedMessages(String conversationId) async =>
      const [];

  @override
  Future<({List<ChatMessage> messages, bool hasMore})> cachedMessagesPage(
    String conversationId, {
    int limit = 60,
    DateTime? before,
  }) async => (messages: <ChatMessage>[], hasMore: false);

  @override
  Future<ChatMessage?> newestOutgoing(String conversationId) async => null;

  @override
  Future<void> deleteConversationLocally(String conversationId) async {}

  @override
  Future<UserProfile?> cachedProfile(String id) async => null;

  @override
  Future<List<UserProfile>> allCachedProfiles() async => const [];

  @override
  Future<List<ConversationSummary>> cachedConversations() async => const [];

  @override
  Future<void> deleteLocal(String clientMessageId) async {}

  @override
  Future<void> enqueueOutbox(ChatMessage m) async {}

  @override
  Future<void> enqueueReaction({
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<LocalMessage?> findLocal(String id) async => null;

  @override
  Future<String?> getDeviceCursor(String key) async => null;

  @override
  Future<String?> getSyncValue(String key) async => null;

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<void> markMessagesRead(String conversationId) async {}

  @override
  Future<int> countUnreadIncoming(String conversationId) async => 0;

  @override
  Future<Map<String, int>> countUnreadIncomingFor(
    List<String> conversationIds,
  ) async => const {};

  @override
  Future<void> markLocalFailed(String clientMessageId) async {}

  @override
  Future<void> markOutboxAttempted(String id, int attempt) async {}

  @override
  Future<void> markReactionAttempted(
    String messageId,
    String emoji,
    int attempt,
  ) async {}

  @override
  Future<List<OutboxMessage>> pendingOutbox() async => const [];

  @override
  Future<List<MessageReactionsOutboxData>> pendingReactions() async => const [];

  @override
  Future<void> removeFromOutbox(String id) async {}

  @override
  Future<int> pendingOutboxCount() async => 0;

  @override
  Future<void> updateOutboxMedia(String id, String? mediaJson) async {}

  @override
  Future<void> removeReactionFromOutbox(String messageId, String emoji) async {}

  @override
  Future<void> replaceLocalMessage(
    String clientMessageId,
    ChatMessage serverMessage,
  ) async {}

  @override
  Future<void> setDeviceCursor(String key, String? cursor) async {}

  @override
  Future<void> setSyncValue(String key, String value) async {}

  @override
  Future<void> updateReceipt({
    required String serverId,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) async {}

  @override
  Future<void> updateReactions(
    String messageId,
    List<MessageReaction> reactions,
  ) async {}

  @override
  Future<void> cacheUserSettings(String userId, String settingsJson) async {}

  @override
  Future<String?> cachedUserSettings(String userId) async => null;

  @override
  Future<String?> findDirectConversationWith(String peerId) async => null;

  @override
  Future<int> upsertWithTarget<T extends drift.Table, D>(
    drift.InsertStatement<T, D> statement,
    drift.Insertable<D> entity,
    List<drift.Column<Object>> target,
  ) async => 0;

  @override
  Future<void> upsertConversation(ConversationSummary c) async {}

  @override
  Future<void> upsertConversations(List<ConversationSummary> chats) async {}

  @override
  Future<void> upsertLocalMessage(ChatMessage m) async {}

  @override
  Future<void> upsertProfile(UserProfile p) async {}

  @override
  Future<void> upsertRemoteMessage(ChatMessage m) async {}
}

Widget _buildApp({
  required FakeConnectivityService connectivity,
  AppUser? user,
}) {
  return _buildAppWithAuth(
    connectivity: connectivity,
    auth: FakeAuthRepository(user: user),
  );
}

/// Renders the onboarding form on its own, so a save can be driven directly
/// without going through the welcome screen.
Widget _setupHarness(AuthRepository auth) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig),
      connectivityServiceProvider.overrideWithValue(FakeConnectivityService()),
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
      localStoreProvider.overrideWithValue(FakeLocalStore()),
    ],
    child: const MaterialApp(home: SetupProfilePage()),
  );
}

Widget _buildAppWithAuth({
  required FakeConnectivityService connectivity,
  required AuthRepository auth,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig),
      connectivityServiceProvider.overrideWithValue(connectivity),
      authRepositoryProvider.overrideWithValue(auth),
      conversationsRepositoryProvider.overrideWithValue(
        FakeConversationsRepository(),
      ),
      messagesRepositoryProvider.overrideWithValue(FakeMessagesRepository()),
      // The relay talks to the Supabase client directly; the harness has no client.
      relayRepositoryProvider.overrideWithValue(FakeRelayRepository()),
      peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
      localStoreProvider.overrideWithValue(FakeLocalStore()),
    ],
    child: const CrystalMessengerApp(),
  );
}

Widget _bannerHarness(FakeConnectivityService connectivity) {
  return ProviderScope(
    overrides: [connectivityServiceProvider.overrideWithValue(connectivity)],
    child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('boots to the welcome page when signed out', (tester) async {
    await tester.pumpWidget(
      _buildApp(connectivity: FakeConnectivityService(), user: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crystal Messenger'), findsOneWidget);
    // The primary call to action is a real button, not a slide control: the
    // reported bug was that tapping "Get started" did nothing because the
    // gesture was undiscoverable and the control latched itself shut.
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);

    // It must be genuinely tappable, i.e. its onPressed is wired up. Checking
    // enabled-ness rather than a spinner, because the test's fake repository
    // resolves synchronously so no busy frame is ever rendered.
    final getStarted = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('GET STARTED'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(getStarted.onPressed, isNotNull);
  });

  testWidgets('boots to the home shell when signed in', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        connectivity: FakeConnectivityService(),
        user: const AppUser(id: 'me', email: 'me@example.com'),
      ),
    );
    await tester.pumpAndSettle();

    // WhatsApp-style shell: no profile bottom tab; Chats/Updates/Calls appear
    // in the top tab bar AND the bottom navigation, so each label is expected
    // multiple times. Calling was removed, but the Calls slot stays so the
    // other two tabs remain centred; it renders an explicit empty state.
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Updates'), findsWidgets);
    expect(find.text('Calls'), findsWidgets);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets(
    'cold start with a persisted-but-restoring session never shows onboarding',
    (tester) async {
      await tester.pumpWidget(
        _buildAppWithAuth(
          connectivity: FakeConnectivityService(),
          auth: RestoringAuthRepository(
            deliveredUser: const AppUser(id: 'me', email: 'me@example.com'),
          ),
        ),
      );

      // First frame: async restore still in flight — must NOT be onboarding.
      await tester.pump();
      expect(find.text('CONTINUE AS GUEST'), findsNothing);

      // Window before the recovery event lands: still no onboarding.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CONTINUE AS GUEST'), findsNothing);

      // Recovery delivered: the app sat in the (empty) shell and is now signed
      // in — onboarding never appeared once.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('CONTINUE AS GUEST'), findsNothing);
      expect(find.text('Chats'), findsWidgets);
    },
  );

  // --- Onboarding: the "AGREE AND CONTINUE does nothing" regression ---------
  //
  // The reported symptom was a setup form whose submit button appeared inert.
  // Two independent causes are pinned here:
  //   1. the save awaited a profile re-read, so any failure on that read left
  //      the router bouncing the user back to /setup with no error shown;
  //   2. the redirect treated a failed profile read as "profile incomplete".

  group('onboarding completes', () {
    testWidgets('saving the profile leaves the form in a completed state', (
      tester,
    ) async {
      // Start with an INCOMPLETE profile, as a fresh guest has.
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'me', email: 'me@example.com'),
        profile: const UserProfile(id: 'me', displayName: '', phone: ''),
      );
      await tester.pumpWidget(_setupHarness(auth));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Ada Lovelace',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter phone number'),
        '8012345678',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AGREE AND CONTINUE'));
      await tester.pumpAndSettle();

      // The write must have landed...
      expect(auth.profile.displayName, 'Ada Lovelace');
      expect(auth.profile.phone, isNotEmpty);
      // ...and the provider must hold a complete profile, so the router's
      // profile-completeness check passes without a second round trip.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetupProfilePage)),
      );
      final saved = container.read(ownProfileProvider).valueOrNull;
      expect(saved?.displayName, 'Ada Lovelace');
      expect(saved?.phone.trim(), isNotEmpty);
    });

    testWidgets('a failing profile re-read does not lose the completed save', (
      tester,
    ) async {
      // The re-read fails (schema gap / offline) but the write succeeded. The
      // form must still reflect a completed profile rather than reverting to
      // an empty one, which is what made the button look like a no-op.
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'me', email: 'me@example.com'),
        profile: const UserProfile(id: 'me', displayName: '', phone: ''),
      )..failProfileFetch = true;

      await tester.pumpWidget(_setupHarness(auth));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Grace Hopper',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter phone number'),
        '8012345678',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AGREE AND CONTINUE'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetupProfilePage)),
      );
      final saved = container.read(ownProfileProvider).valueOrNull;
      expect(
        saved?.displayName,
        'Grace Hopper',
        reason: 'the locally-applied save must survive a failed re-read',
      );
    });

    testWidgets('the button refuses to submit an empty phone number', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        user: const AppUser(id: 'me', email: 'me@example.com'),
        profile: const UserProfile(id: 'me', displayName: '', phone: ''),
      );
      await tester.pumpWidget(_setupHarness(auth));
      await tester.pumpAndSettle();

      // Name only: form validation should block it rather than saving an
      // identity the router would reject (bouncing straight back to /setup).
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'No Phone',
      );
      await tester.tap(find.text('AGREE AND CONTINUE'));
      await tester.pumpAndSettle();

      expect(auth.profile.displayName, isEmpty);
      expect(find.text('Required'), findsWidgets);
    });
  });

  testWidgets('does not show the offline banner while online', (tester) async {
    await tester.pumpWidget(_bannerHarness(FakeConnectivityService()));
    await tester.pumpAndSettle();

    expect(find.textContaining('You are offline'), findsNothing);
  });

  testWidgets('shows the offline banner when connectivity drops', (
    tester,
  ) async {
    final connectivity = FakeConnectivityService(online: true);
    await tester.pumpWidget(_bannerHarness(connectivity));
    await tester.pumpAndSettle();

    connectivity.setOnline(false);
    await tester.pumpAndSettle();

    expect(find.textContaining('You are offline'), findsOneWidget);
  });

  testWidgets('hides the offline banner when connectivity returns', (
    tester,
  ) async {
    final connectivity = FakeConnectivityService(online: false);
    await tester.pumpWidget(_bannerHarness(connectivity));
    await tester.pumpAndSettle();

    expect(find.textContaining('You are offline'), findsOneWidget);

    connectivity.setOnline(true);
    await tester.pumpAndSettle();

    expect(find.textContaining('You are offline'), findsNothing);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
  });
}
