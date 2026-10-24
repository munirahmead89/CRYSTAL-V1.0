import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/conversations/domain/repositories/chat_repositories.dart';
import '../../features/delivery/domain/message_lifecycle.dart';
import '../../features/delivery/domain/relay_envelope.dart';
import '../../features/delivery/domain/repositories/relay_repository.dart';
import '../../shared/models/chat_message.dart';
import '../database/database.dart';
import '../database/local_store.dart';
import '../errors/app_exceptions.dart';
import '../media/media_manifest.dart';

/// Result of a single outbox flush pass.
class OutboxFlushResult {
  const OutboxFlushResult({
    this.pushedMessages = 0,
    this.pushedReactions = 0,
    this.pendingMessages = false,
    this.pendingReactions = false,
  });

  final int pushedMessages;
  final int pushedReactions;
  final bool pendingMessages;
  final bool pendingReactions;

  bool get hasPending => pendingMessages || pendingReactions;

  OutboxFlushResult merge(OutboxFlushResult other) => OutboxFlushResult(
    pushedMessages: pushedMessages + other.pushedMessages,
    pushedReactions: pushedReactions + other.pushedReactions,
    pendingMessages: pendingMessages || other.pendingMessages,
    pendingReactions: pendingReactions || other.pendingReactions,
  );
}

/// Flushes queued messages and reactions to the server once connectivity is
/// restored, using exponential backoff between full-flush passes.
///
/// The outbox makes send "instant": the message is cached locally the moment
/// it is composed and pushed to Supabase opportunistically. If a pass leaves
/// work behind (server hiccup, offline), a retry is scheduled with a growing
/// delay capped at [backoffCap]. Rows that exhaust their attempts are marked
/// failed locally so the UI can offer a retry.
class OutboxSyncEngine {
  OutboxSyncEngine({
    required this.store,
    required this.messagesRepository,
    this.relay,
    required this.getMyId,
    this.mediaUpload,
    this.onError,
    this.isOnline,
  });

  final LocalStore store;
  final MessagesRepository messagesRepository;

  /// The trusted send path.
  ///
  /// Preferred over [messagesRepository] because `send_message` validates
  /// membership, rate limit, type and size server-side and is idempotent on
  /// `client_message_id`. A direct table INSERT can do none of that with an anon
  /// key, which is how "delivered" used to become a claim rather than a fact.
  final RelayRepository? relay;

  final String Function() getMyId;

  /// Observes errors that would otherwise be swallowed by the retry loop.
  ///
  /// Production leaves this null; the outbox intentionally treats a send
  /// failure as "try again later" rather than surfacing it, and without a hook
  /// there is no way to tell a genuine bug from an expected network error.
  final void Function(Object error, StackTrace stack)? onError;

  /// Whether the device currently has a usable connection.
  ///
  /// When this reports false the engine does no network work at all: no upload
  /// is attempted, no send is tried, and — importantly — no attempt is
  /// consumed. Without that last part, a message composed offline would burn
  /// through its retry budget while simply waiting for a network and end up
  /// painted with the "failed" affordance, which is a lie: nothing about the
  /// message is broken.
  ///
  /// Defaults to always-online so callers that do not track connectivity (and
  /// tests) behave exactly as before.
  final bool Function()? isOnline;

  /// Uploads a queued attachment and returns its manifest.
  ///
  /// Injected rather than constructed here so the engine stays independent of
  /// Supabase Storage; `null` disables media queueing (text only).
  final Future<MediaManifest> Function({
    required String conversationId,
    required String filePath,
    String? fileName,
    String? mimeType,
  })?
  mediaUpload;

  static const maxAttempts = 6;
  static const mediaMaxAttempts = 3;
  static const maxReactionAttempts = 5;

  /// 1s -> 2s -> 4s -> … capped at 30s.
  static const backoffBase = Duration(seconds: 1);
  static const backoffCap = Duration(seconds: 30);

  Timer? _retryTimer;
  Duration _nextBackoff = backoffBase;
  bool _flushing = false;

  /// Flushing again right now, on the caller's back (connectivity restored,
  /// app foregrounded, user tapped retry).
  bool _flushRequested = false;

  /// Advances the backoff schedule by one step (doubling, capped).
  Duration _advanceBackoff() {
    final next = _nextBackoff * 2;
    _nextBackoff = next >= backoffCap ? backoffCap : next;
    return _nextBackoff;
  }

  void _resetBackoff() {
    _nextBackoff = backoffBase;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _advanceBackoff();
    _retryTimer = Timer(delay, () {
      if (!_flushing) flush();
    });
  }

  /// Flushes immediately, ignoring the backoff schedule and resetting it.
  ///
  /// This is what makes a message composed offline go out the instant the
  /// network comes back rather than up to [backoffCap] seconds later, which is
  /// the difference between feeling like WhatsApp and feeling broken. Concurrent
  /// callers collapse into a single in-flight flush plus one follow-up pass, so
  /// a burst of connectivity events cannot stack up work.
  Future<OutboxFlushResult> flushNow() {
    if (_flushing) {
      _flushRequested = true;
      final inFlight = _inFlight;
      if (inFlight != null) return inFlight;
      return Future<OutboxFlushResult>.value(const OutboxFlushResult());
    }
    _retryTimer?.cancel();
    _resetBackoff();
    return flush();
  }

  Future<OutboxFlushResult>? _inFlight;

  /// Processes every pending outbox row and reaction. Rows are retried
  /// indefinitely; the attempt count only controls the UI's "failed" badge.
  Future<OutboxFlushResult> flush() async {
    if (_flushing) return _inFlight ?? const OutboxFlushResult();
    _flushing = true;
    final completer = Completer<OutboxFlushResult>();
    _inFlight = completer.future;
    try {
      OutboxFlushResult outcome = const OutboxFlushResult();
      // Loop so a flush that was requested while this one was running is
      // honoured within the same call.
      do {
        _flushRequested = false;
        outcome = (await _flushMessages()).merge(await _flushReactions());
      } while (_flushRequested);

      if (outcome.hasPending) {
        _scheduleRetry();
      } else {
        _retryTimer?.cancel();
        _resetBackoff();
      }
      completer.complete(outcome);
      return outcome;
    } catch (error, stack) {
      completer.completeError(error, stack);
      rethrow;
    } finally {
      _flushing = false;
      _inFlight = null;
    }
  }

  Future<OutboxFlushResult> _flushMessages() async {
    final pending = await store.pendingOutbox();
    if (pending.isEmpty) return const OutboxFlushResult();

    // Offline: leave every row exactly as it is. No attempt is consumed and
    // nothing is marked failed, so a queued message keeps its honest "waiting"
    // state until the network actually returns.
    if (isOnline?.call() == false) {
      return OutboxFlushResult(pendingMessages: true);
    }

    final me = getMyId();
    var pushed = 0;

    for (final row in pending) {
      try {
        var draft = _draft(row, me);

        // Media queued while offline is still just a local file at this point.
        // Upload it now, and only then post the message, so the receiver
        // never sees a message whose attachment does not exist yet.
        draft = await _ensureMediaUploaded(row, draft);

        final server = await _send(draft);
        await store.replaceLocalMessage(row.id, server);
        await store.removeFromOutbox(row.id);
        await _discardStagedFile(draft.attachment?.localPath);
        pushed++;
      } catch (error, stack) {
        onError?.call(error, stack);
        final next = row.attemptCount + 1;
        await store.markOutboxAttempted(row.id, next);
        // Once the attempt budget is spent the bubble shows the retry
        // affordance, but the row is deliberately KEPT: the next pass will
        // still send it, and deleting it would strand a message the user has
        // already been shown.
        if (next >= maxAttemptsFor(row.type)) {
          await store.markLocalFailed(row.id);
        }
      }
    }

    final left = await store.pendingOutbox();
    return OutboxFlushResult(
      pushedMessages: pushed,
      pendingMessages: left.isNotEmpty,
    );
  }

  /// Uploads one queued message through the trusted relay.
  ///
  /// Falls back to the legacy repository only when no [relay] was injected, so
  /// existing callers and tests keep working while every production path goes
  /// through `send_message`.
  ///
  /// The returned message is the server's authoritative row, whether this call
  /// stored it or recovered a previous attempt. Both are success: a
  /// [SendOutcome.recovered] means a response was lost, and treating that as a
  /// failure would burn the retry budget on a message the server already has.
  Future<ChatMessage> _send(ChatMessage draft) async {
    final relayRepository = relay;
    if (relayRepository != null) {
      final result = await relayRepository.sendMessage(
        RelaySendRequest(
          conversationId: draft.conversationId,
          clientMessageId: draft.clientMessageId,
          type: RelayMessageType.parse(draft.type),
          payload: draft.body,
          media: draft.attachment?.toServerJson(),
          replyToMessageId: draft.replyToId,
          forwarded: draft.forwarded,
        ),
      );
      return _fromEnvelope(result.envelope, myId: draft.senderId);
    }
    return messagesRepository.send(draft);
  }

  ChatMessage _fromEnvelope(RelayEnvelope envelope, {required String myId}) {
    return ChatMessage(
      id: envelope.clientMessageId,
      clientMessageId: envelope.clientMessageId,
      // The local row is re-keyed by `replaceLocalMessage`, so the client's
      // identity has to be preserved here or the row would be duplicated.
      conversationId: envelope.conversationId,
      senderId: envelope.senderId,
      type: envelope.type.wireValue,
      body: envelope.payload,
      attachment: envelope.ciphertext == null && envelope.mediaJson != null
          ? _media(envelope.mediaJson)
          : null,
      reactions: const [],
      replyToId: envelope.replyToMessageId,
      forwarded: envelope.forwarded,
      // Server receipt time is authoritative for ordering; the local clock is
      // only what the user saw as "now" when they hit send.
      createdAt: envelope.serverCreatedAt,
      editedAt: envelope.editedAt,
      deleted: envelope.isDeleted,
      outgoing: myId.isNotEmpty ? envelope.senderId == myId : true,
      localState: MessageLocalState.sent,
      remoteStatus: envelope.readAt != null
          ? RemoteStatus.seen
          : (envelope.deliveredAt != null
                ? RemoteStatus.delivered
                : RemoteStatus.sent),
      deliveredAt: envelope.deliveredAt,
      readAt: envelope.readAt,
    );
  }

  /// Per-type attempt budget for showing the "failed" state in the UI.
  int maxAttemptsFor(String type) =>
      type == 'text' ? maxAttempts : mediaMaxAttempts;

  /// Deletes staged copies of files that no longer belong to any queued
  /// message.
  ///
  /// A staged file is the only copy of an attachment the user has not managed
  /// to send yet, so it is only removed once the outbox has no reference to it.
  /// Run at startup to reclaim files orphaned by a crash between staging and
  /// enqueueing, which would otherwise accumulate and quietly fill the device.
  Future<int> sweepOrphanedStagedFiles() async {
    final referenced = <String>{};
    for (final row in await store.pendingOutbox()) {
      final path = _media(row.mediaJson)?.localPath;
      if (path != null && path.isNotEmpty) referenced.add(path);
    }
    if (referenced.isEmpty && _stagedRoot == null) return 0;

    final root = _stagedRoot ?? await _resolveStagedRoot();
    if (root == null || !await root.exists()) return 0;

    var removed = 0;
    await for (final entity in root.list()) {
      if (entity is! File) continue;
      if (referenced.contains(entity.path)) continue;
      try {
        await entity.delete();
        removed++;
      } catch (_) {
        // A file we cannot delete is left alone rather than failing the sweep.
      }
    }
    return removed;
  }

  Directory? _stagedRoot;

  Future<Directory?> _resolveStagedRoot() async {
    _stagedRoot ??= Directory(
      p.join((await getApplicationSupportDirectory()).path, 'outgoing_media'),
    );
    return _stagedRoot;
  }

  /// Deletes the staged copy of a file that has now been uploaded.
  ///
  /// Only ever called after the message is confirmed on the server, so a
  /// failure can never destroy the only local copy of a user's attachment.
  Future<void> _discardStagedFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Housekeeping: a leftover file is reclaimed by the next app start's
      // sweep, and must never fail an otherwise successful send.
    }
  }

  /// Uploads the attachment of a queued media message, if it has not been
  /// uploaded yet, and returns a draft whose attachment carries the manifest.
  ///
  /// Idempotent: once the message row's stored attachment has an `upload_id`
  /// this is a no-op, so a retry after a failure mid-upload resumes the chunked
  /// transfer instead of starting over.
  Future<ChatMessage> _ensureMediaUploaded(
    OutboxMessage row,
    ChatMessage draft,
  ) async {
    final attachment = draft.attachment;
    final upload = mediaUpload;
    if (attachment == null || upload == null) return draft;
    if (attachment.isChunked) return draft;

    final localPath = attachment.localPath;
    if (localPath == null || localPath.isEmpty) return draft;
    if (!await File(localPath).exists()) {
      throw MediaTransferException(
        'The queued file is no longer on this device, so it cannot be sent.',
      );
    }

    final manifest = await upload(
      conversationId: row.conversationId,
      filePath: localPath,
      fileName: attachment.name,
      mimeType: attachment.mimeType,
    );

    // Persist the manifest against the outbox row so a later attempt reuses the
    // already-uploaded parts rather than re-sending gigabytes.
    final uploaded = Attachment(
      name: manifest.fileName,
      mimeType: manifest.mimeType,
      sizeBytes: manifest.totalBytes,
      uploadId: manifest.uploadId,
      partCount: manifest.partCount,
      partBytes: manifest.partBytes,
      sha256: manifest.sha256,
    );
    await store.updateOutboxMedia(row.id, _encodeMedia(uploaded));

    return ChatMessage(
      id: draft.id,
      clientMessageId: draft.clientMessageId,
      conversationId: draft.conversationId,
      senderId: draft.senderId,
      type: draft.type,
      body: draft.body,
      attachment: uploaded,
      createdAt: draft.createdAt,
      outgoing: true,
      localState: MessageLocalState.sending,
    );
  }

  Future<OutboxFlushResult> _flushReactions() async {
    final pending = await store.pendingReactions();
    if (pending.isEmpty) return const OutboxFlushResult();
    var pushed = 0;
    var remaining = false;
    for (final row in pending) {
      if (row.attemptCount >= maxReactionAttempts) continue;
      try {
        final aggregate = await messagesRepository.setReaction(
          messageId: row.messageId,
          emoji: row.emoji,
        );
        await store.updateReactions(row.messageId, aggregate);
        await store.removeReactionFromOutbox(row.messageId, row.emoji);
        pushed++;
      } catch (_) {
        final next = row.attemptCount + 1;
        if (next >= maxReactionAttempts) {
          await store.removeReactionFromOutbox(row.messageId, row.emoji);
        } else {
          await store.markReactionAttempted(row.messageId, row.emoji, next);
          remaining = true;
        }
      }
    }
    return OutboxFlushResult(
      pushedReactions: pushed,
      pendingReactions:
          remaining || (await store.pendingReactions()).isNotEmpty,
    );
  }

  ChatMessage _draft(OutboxMessage row, String myId) {
    return ChatMessage(
      id: row.id,
      clientMessageId: row.id,
      conversationId: row.conversationId,
      senderId: myId,
      type: row.type,
      body: row.body,
      attachment: _media(row.mediaJson),
      // Carried through from the queue. Dropping it here is what made a reply
      // composed offline arrive as an unanchored message.
      replyToId: row.replyToId,
      forwarded: row.forwarded,
      createdAt: row.createdAt,
      outgoing: true,
      localState: MessageLocalState.sending,
    );
  }
}

Attachment? _media(String? raw) {
  if (raw == null) return null;
  try {
    return Attachment.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  } catch (_) {
    return null;
  }
}

String? _encodeMedia(Attachment? attachment) =>
    attachment == null ? null : jsonEncode(attachment.toJson());
