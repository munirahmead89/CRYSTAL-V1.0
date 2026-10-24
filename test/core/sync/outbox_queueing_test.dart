import 'dart:io';

import 'package:crystal_messenger/core/database/database.dart';
import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/core/errors/app_exceptions.dart';
import 'package:crystal_messenger/core/media/media_manifest.dart';
import 'package:crystal_messenger/core/sync/outbox_sync.dart';
import 'package:crystal_messenger/features/conversations/domain/repositories/chat_repositories.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:crystal_messenger/shared/models/user_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A messages repository whose network behaviour the test controls.
///
/// `failSends` simulates the device being offline: every send throws, exactly
/// as a real socket failure would.
class _FakeMessagesRepository implements MessagesRepository {
  _FakeMessagesRepository();

  /// True while the simulated device has no connection.
  bool failSends = false;
  int sendCount = 0;
  final List<ChatMessage> sent = [];

  void setOffline() => failSends = true;
  void setOnline() => failSends = false;

  @override
  Future<ChatMessage> send(ChatMessage draft) async {
    sendCount++;
    if (failSends) {
      throw const MediaTransferException('offline');
    }
    sent.add(draft);
    return ChatMessage(
      id: 'server-${draft.clientMessageId}',
      clientMessageId: draft.clientMessageId,
      conversationId: draft.conversationId,
      senderId: draft.senderId,
      type: draft.type,
      body: draft.body,
      attachment: draft.attachment,
      createdAt: draft.createdAt,
      outgoing: true,
      localState: MessageLocalState.sent,
    );
  }

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
  Future<List<MessageReaction>> setReaction({
    required String messageId,
    String? emoji,
  }) async => const [];

  final edits = <({String messageId, String body})>[];

  @override
  Future<void> editText({
    required String messageId,
    required String body,
  }) async {
    edits.add((messageId: messageId, body: body));
  }
}

void main() {
  late AppDatabase db;
  late LocalStore store;
  late _FakeMessagesRepository messages;
  late OutboxSyncEngine engine;

  const me = 'me-1';
  const conversationId = 'conv-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalStore(db);
    messages = _FakeMessagesRepository();
    engine = OutboxSyncEngine(
      store: store,
      messagesRepository: messages,
      getMyId: () => me,
      isOnline: () => !messages.failSends,
    );
  });

  tearDown(() async {
    await db.close();
  });

  ChatMessage textMessage(String body) => ChatMessage(
    id: 'm-$body',
    clientMessageId: 'm-$body',
    conversationId: conversationId,
    senderId: me,
    body: body,
    createdAt: DateTime.now(),
    outgoing: true,
    localState: MessageLocalState.queued,
  );

  group('offline text queueing', () {
    test(
      'a message composed offline is held, not lost, and sends on reconnect',
      () async {
        messages.setOffline();

        final message = textMessage('hello');
        await store.upsertLocalMessage(message);
        await store.enqueueOutbox(message);

        // Several failed passes while still offline.
        for (var i = 0; i < 8; i++) {
          await engine.flush();
        }

        // The regression this guards: the outbox used to DELETE a row once it
        // exhausted its retries, which stranded the message forever - the user
        // saw it in the thread but it could never be sent.
        expect(
          await store.pendingOutboxCount(),
          1,
          reason: 'an exhausted message must stay queued until it is sent',
        );
        expect(messages.sent, isEmpty);

        // Network returns.
        messages.setOnline();
        await engine.flushNow();

        expect(messages.sent, hasLength(1));
        expect(messages.sent.single.body, 'hello');
        expect(
          await store.pendingOutboxCount(),
          0,
          reason: 'the row is removed only once the server confirmed it',
        );
      },
    );

    test('send order is preserved (oldest first)', () async {
      for (final body in ['first', 'second', 'third']) {
        final m = ChatMessage(
          id: 'm-$body',
          clientMessageId: 'm-$body',
          conversationId: conversationId,
          senderId: me,
          body: body,
          createdAt: DateTime.now(),
          outgoing: true,
          localState: MessageLocalState.queued,
        );
        await store.upsertLocalMessage(m);
        await store.enqueueOutbox(m);
      }

      await engine.flushNow();

      expect(messages.sent.map((m) => m.body).toList(), [
        'first',
        'second',
        'third',
      ]);
    });

    test('a message queued in a previous session is sent at startup', () async {
      // Simulates the outbox row surviving a process kill.
      final m = textMessage('survivor');
      await store.upsertLocalMessage(m);
      await store.enqueueOutbox(m);

      expect(await store.pendingOutboxCount(), 1);
      await engine.flushNow();
      expect(messages.sent.single.body, 'survivor');
    });

    test('the local message keeps its queued state while offline', () async {
      messages.setOffline();
      final m = textMessage('pending');
      await store.upsertLocalMessage(m);
      await store.enqueueOutbox(m);
      await engine.flush();

      final local = await store.findLocal(m.clientMessageId);
      // "failed" is what paints the retry affordance; the row is still queued
      // for sending either way.
      expect(local, isNotNull);
      expect(local!.localState, isNot(MessageLocalState.sent));
    });

    test('being offline does not consume retry attempts', () async {
      // The UX bug this guards: a message waiting for a network used to burn
      // through its attempt budget and end up marked "failed" - a red error
      // dot on a message that is perfectly fine and about to go out.
      messages.setOffline();
      final m = textMessage('waiting');
      await store.upsertLocalMessage(m);
      await store.enqueueOutbox(m);

      for (var i = 0; i < 10; i++) {
        await engine.flush();
      }

      final row = (await store.pendingOutbox()).single;
      expect(row.attemptCount, 0, reason: 'no attempt should be spent offline');

      final local = await store.findLocal(m.clientMessageId);
      expect(
        local!.localState,
        isNot(MessageLocalState.failed),
        reason: 'a message waiting for a network is not a failed message',
      );
    });
  });

  group('offline media queueing', () {
    late Directory staging;
    late String videoPath;

    setUp(() async {
      staging = await Directory.systemTemp.createTemp('crystal_outbox');
      videoPath = '${staging.path}/clip.mp4';
      await File(videoPath).writeAsBytes(List<int>.filled(2048, 7));
    });

    tearDown(() async {
      if (await staging.exists()) await staging.delete(recursive: true);
    });

    test('media composed offline is uploaded then sent on reconnect', () async {
      var uploadedPath = '';
      var uploadCalls = 0;
      final captured = <Object>[];

      final withMedia = OutboxSyncEngine(
        store: store,
        messagesRepository: messages,
        getMyId: () => me,
        onError: (error, _) => captured.add(error),
        isOnline: () => !messages.failSends,
        mediaUpload:
            ({
              required String conversationId,
              required String filePath,
              String? fileName,
              String? mimeType,
            }) async {
              uploadCalls++;
              uploadedPath = filePath;
              return MediaManifest(
                uploadId: 'upload-1',
                conversationId: conversationId,
                fileName: fileName ?? 'clip.mp4',
                mimeType: mimeType,
                totalBytes: await File(filePath).length(),
                partBytes: MediaManifest.kDefaultPartBytes,
                partCount: 1,
                sha256: 'a' * 64,
              );
            },
      );

      messages.setOffline();

      final m = ChatMessage(
        id: 'm-video',
        clientMessageId: 'm-video',
        conversationId: conversationId,
        senderId: me,
        type: 'video',
        attachment: Attachment(
          name: 'clip.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 2048,
          localPath: videoPath,
        ),
        createdAt: DateTime.now(),
        outgoing: true,
        localState: MessageLocalState.queued,
      );
      await store.upsertLocalMessage(m);
      await store.enqueueOutbox(m);

      // Offline: nothing uploads, nothing sends, but the message is retained.
      await withMedia.flush();
      expect(uploadCalls, 0);
      expect(messages.sent, isEmpty);
      expect(await store.pendingOutboxCount(), 1);

      // Reconnect.
      messages.setOnline();
      await withMedia.flushNow();

      expect(uploadCalls, 1, reason: 'the queued file is uploaded once online');
      expect(uploadedPath, videoPath);
      expect(messages.sent, hasLength(1));

      final sentAttachment = messages.sent.single.attachment!;
      expect(sentAttachment.uploadId, 'upload-1');
      expect(sentAttachment.isChunked, isTrue);
      expect(captured, isEmpty, reason: 'no flush error should be swallowed');
      expect(await store.pendingOutboxCount(), 0);
    });

    test(
      'a device-local path is never written to the server payload',
      () async {
        final withMedia = OutboxSyncEngine(
          store: store,
          messagesRepository: messages,
          getMyId: () => me,
          mediaUpload:
              ({
                required String conversationId,
                required String filePath,
                String? fileName,
                String? mimeType,
              }) async => MediaManifest(
                uploadId: 'upload-2',
                conversationId: conversationId,
                fileName: fileName ?? 'x',
                mimeType: mimeType,
                totalBytes: 10,
                partBytes: MediaManifest.kDefaultPartBytes,
                partCount: 1,
                sha256: 'b' * 64,
              ),
        );

        final m = ChatMessage(
          id: 'm-video',
          clientMessageId: 'm-video',
          conversationId: conversationId,
          senderId: me,
          type: 'video',
          attachment: Attachment(
            name: 'clip.mp4',
            mimeType: 'video/mp4',
            localPath: videoPath,
          ),
          createdAt: DateTime.now(),
          outgoing: true,
          localState: MessageLocalState.queued,
        );
        await store.upsertLocalMessage(m);
        await store.enqueueOutbox(m);

        await withMedia.flushNow();

        // The uploaded attachment replaces the queued one, so no local path
        // survives into what gets posted.
        final payload = messages.sent.single.attachment!;
        expect(payload.toServerJson().containsKey('local_path'), isFalse);
      },
    );

    test(
      'a staged file missing from disk does not send a broken message',
      () async {
        var uploadCalls = 0;
        final withMedia = OutboxSyncEngine(
          store: store,
          messagesRepository: messages,
          getMyId: () => me,
          mediaUpload:
              ({
                required String conversationId,
                required String filePath,
                String? fileName,
                String? mimeType,
              }) async {
                uploadCalls++;
                return MediaManifest(
                  uploadId: 'u',
                  conversationId: conversationId,
                  fileName: 'x',
                  mimeType: mimeType,
                  totalBytes: 1,
                  partBytes: 1000,
                  partCount: 1,
                );
              },
        );

        final m = ChatMessage(
          id: 'm-gone',
          clientMessageId: 'm-gone',
          conversationId: conversationId,
          senderId: me,
          type: 'video',
          attachment: Attachment(
            name: 'gone.mp4',
            mimeType: 'video/mp4',
            localPath: '${staging.path}/does-not-exist.mp4',
          ),
          createdAt: DateTime.now(),
          outgoing: true,
          localState: MessageLocalState.queued,
        );
        await store.upsertLocalMessage(m);
        await store.enqueueOutbox(m);

        await withMedia.flushNow();

        expect(uploadCalls, 0);
        expect(
          messages.sent,
          isEmpty,
          reason: 'a message whose bytes are gone must not be posted',
        );
        expect(await store.pendingOutboxCount(), 1);
      },
    );
  });

  group('profile cache', () {
    test('a cached profile round-trips through SQLite', () async {
      final profile = UserProfile(
        id: 'peer-1',
        displayName: 'Ada',
        phone: '+2348012345678',
        avatarUrl: 'https://example.test/a.jpg',
        bio: 'hi',
        presence: 'online',
      );
      await store.upsertProfile(profile);

      final cached = await store.cachedProfile('peer-1');
      expect(cached, isNotNull);
      expect(cached!.displayName, 'Ada');
      expect(cached.phone, '+2348012345678');
      expect(cached.avatarUrl, 'https://example.test/a.jpg');
    });

    test(
      'profiles can be found by phone for offline sign-in restore',
      () async {
        await store.upsertProfile(
          UserProfile(
            id: 'peer-2',
            displayName: 'Grace',
            phone: '+2348099999999',
          ),
        );
        final found = await store.cacheProfileByPhone('+2348099999999');
        expect(found, hasLength(1));
        expect(found.single.displayName, 'Grace');
      },
    );

    test('the local mirror is searchable, like the contacts list', () async {
      for (final entry in [
        ('p1', 'Ada Lovelace', '+2348010000001'),
        ('p2', 'Grace Hopper', '+2348010000002'),
        ('p3', 'Alan Turing', '+2348010000003'),
      ]) {
        await store.upsertProfile(
          UserProfile(id: entry.$1, displayName: entry.$2, phone: entry.$3),
        );
      }

      final byName = (await store.allCachedProfiles())
          .where((p) => p.displayName.contains('Hop'))
          .toList();
      expect(byName.single.displayName, 'Grace Hopper');

      final byPhone = (await store.allCachedProfiles())
          .where((p) => p.phone.endsWith('003'))
          .toList();
      expect(byPhone.single.displayName, 'Alan Turing');
    });
  });
}
