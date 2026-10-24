import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/media/media_compressor.dart';
import '../../../../core/media/media_providers.dart';
import '../../../../core/media/transfer_progress.dart';
import '../../../../core/media/voice_recorder_controller.dart';
import '../../../../core/media/chunked_uploader.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user_settings.dart';
import '../../../../shared/ui/glass.dart';
import '../../../../shared/ui/media_progress.dart';
import '../../../../shared/ui/motion.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/smooth_progress.dart';
import '../../../../shared/widgets/profile_quick_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../profile/presentation/providers/settings_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/transfer_views.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId, this.initialPeer});

  final String conversationId;
  final ConversationSummary? initialPeer;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _composer = TextEditingController();

  /// Message being replied to, or null. Drives the quote banner above the
  /// field and the `reply_to_id` on the next send.
  ChatMessage? _replyingTo;

  /// Message being edited, or null. Mutually exclusive with [_replyingTo]:
  /// editing a message and replying to it in one composer would be ambiguous.
  ChatMessage? _editing;

  /// Owned so [FocusScope.requestFocus] can open the keyboard for the reply
  /// flow. Passing `true` for a node that is not attached to a field would be a
  /// silent no-op, which is why the field uses this node explicitly.
  final _composerFocus = FocusNode();

  /// One recording per chat, shared by the mic button and the attach sheet so
  /// both entry points drive the same session instead of racing each other.
  final _voice = VoiceRecorderController();
  final _scrollController = ScrollController();
  Timer? _typingDebounce;
  bool _sending = false;

  /// Human-readable transfer state shown next to the composer's spinner.
  String? _sendingLabel;

  /// 0.0-1.0 while a large attachment is streaming up.
  double? _sendingFraction;

  /// "12 MB of 340 MB â€¢ 2.4 MB/s â€¢ 2m 10s left" style detail line.
  String? _sendingEta;

  /// Smooths upload throughput so the ETA does not jump around between parts.
  final _sendSpeed = TransferSpeedEstimator();

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'bmp',
  };
  static const _videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
  static const _audioExtensions = {
    'm4a',
    'aac',
    'mp3',
    'ogg',
    'opus',
    'wav',
    'amr',
    '3gp',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Save current conversation for state restoration
    ref
        .read(appPreferencesProvider.future)
        .then((prefs) => prefs.setLastConversation(widget.conversationId))
        .ignore();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Reversed thread: scrolled to max extent == at the top (oldest) edge.
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .loadOlderMessages();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _typingDebounce?.cancel();
    _composer.dispose();
    _voice.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged(String value) {
    final isTyping = value.trim().isNotEmpty;
    _typingDebounce?.cancel();
    _typingDebounce = Timer(
      const Duration(milliseconds: 600),
      () => ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .sendTyping(isTyping),
    );
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    // Captured before the send so the reply target survives the state change
    // that clears the banner.
    final replyTo = _replyingTo?.id;
    final editing = _editing;

    if (editing != null) {
      final ok = await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .editMessage(editing, text);
      if (!ok) {
        _showResult('Could not edit this message. It may be too old.');
        // Leave the text in the composer so the edit is not lost on failure.
        return;
      }
    } else {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .sendText(text, replyToId: replyTo);
    }

    _composer.clear();
    setState(() {
      _replyingTo = null;
      _editing = null;
    });
  }

  /// Enters reply mode for [message].
  ///
  /// Focus is requested here rather than in the bubble so the keyboard opens
  /// immediately - tapping into reply mode and then having to tap the field
  /// again is the usual way this feature gets abandoned.
  void _startReply(ChatMessage message) {
    setState(() => _replyingTo = message);
    FocusScope.of(context).requestFocus(_composerFocus);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  /// Enters edit mode for [message].
  ///
  /// Reuses the composer so editing feels like replying: the same field, the
  /// same send button, with a visible banner so it is never ambiguous which
  /// mode the user is in.
  void _startEdit(ChatMessage message) {
    setState(() {
      _editing = message;
      _replyingTo = null;
      _composer.text = message.body ?? '';
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
    });
    FocusScope.of(context).requestFocus(_composerFocus);
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _composer.clear();
    });
  }

  /// Confirms and performs "delete for me".
  ///
  /// Always local: it works offline, needs no confirmation about the other
  /// person, and is undoable only in the sense that the message is not gone from
  /// the server — which is stated in the dialog so the user knows what they
  /// chose.
  Future<void> _confirmDeleteForMe(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete for me?'),
        content: const Text(
          'This removes the message from this device only. The other person '
          'keeps their copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .deleteForMe(message);
    if (!mounted) return;
    _showResult(
      outcome.succeeded
          ? 'Removed from this device'
          : (outcome.detail ?? 'Could not delete this message'),
    );
  }

  /// Confirms and performs "delete for everyone".
  ///
  /// The confirmation spells out what cannot be undone, because a user who
  /// believes "delete for everyone" also un-sends a screenshot will be
  /// disappointed later.
  Future<void> _confirmDeleteForEveryone(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
          'The message will be removed for both people, and other devices will '
          'be told to remove it too.\n\n'
          'It cannot be recalled from a screenshot, from a notification that has '
          'already appeared, or from a copy anyone saved outside the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete for everyone'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .deleteForEveryone(message);
    if (!mounted) return;
    _showResult(
      outcome.succeeded
          ? 'Deleted for everyone'
          : (outcome.detail ?? 'Could not delete this message for everyone'),
    );
  }

  void _showResult(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// True when the device currently has a usable connection.
  bool get _online => ref.read(isOnlineProvider).valueOrNull ?? false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      // Downscaling here is a real saving: the original is usually 4-12 MB,
      // which would burn most of the free tier's 5 GB monthly egress on a
      // single conversation screenshot.
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _uploadAndSend(
      type: 'image',
      filePath: picked.path,
      fileName: picked.name,
      mimeType: picked.mimeType,
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: source);
    if (picked == null) return;
    // Only the PATH is passed on. Reading a multi-gigabyte clip into a byte
    // list here is what used to crash the app on large videos.
    await _uploadAndSend(
      type: 'video',
      filePath: picked.path,
      fileName: picked.name,
      mimeType: picked.mimeType ?? 'video/mp4',
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    await _sendPickedFile(result.files.first);
  }

  /// Picks multiple files and uploads them concurrently, each tracked
  /// independently so the user sees per-file progress.
  Future<void> _pickMultipleFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    if (result.files.length == 1) {
      await _sendPickedFile(result.files.first);
      return;
    }
    // Concurrent upload: all files start simultaneously.
    final futures = result.files.map(_sendPickedFile);
    await Future.wait(futures, eagerError: false);
  }

  /// Picks multiple images from the gallery and sends them concurrently.
  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;
    if (picked.length == 1) {
      final img = picked.first;
      await _uploadAndSend(
        type: 'image',
        filePath: img.path,
        fileName: img.name,
        mimeType: img.mimeType,
      );
      return;
    }
    // Send all images concurrently.
    final futures = picked.map(
      (img) => _uploadAndSend(
        type: 'image',
        filePath: img.path,
        fileName: img.name,
        mimeType: img.mimeType,
      ),
    );
    await Future.wait(futures, eagerError: false);
  }

  /// Sends a single [PlatformFile]. Used by both the single-file and
  /// multi-file pickers so the logic is not duplicated.
  Future<void> _sendPickedFile(PlatformFile file) async {
    final path = file.path;
    if (path == null) {
      final bytes = file.bytes;
      if (bytes == null) {
        _snack('${file.name}: could not be read.');
        return;
      }
      final temp = await _writeTempFile(file.name, bytes);
      await _uploadAndSend(
        type: _typeForExtension(file.extension),
        filePath: temp,
        fileName: file.name,
        mimeType: file.extension,
      );
      return;
    }
    await _uploadAndSend(
      type: _typeForExtension(file.extension),
      filePath: path,
      fileName: file.name,
      mimeType: file.extension,
    );
  }

  String _typeForExtension(String? ext) {
    final lower = ext?.toLowerCase();
    if (_imageExtensions.contains(lower)) return 'image';
    if (_videoExtensions.contains(lower)) return 'video';
    if (_audioExtensions.contains(lower)) return 'voice';
    return 'file';
  }

  /// Persists picker-supplied bytes so the uploader can stream from disk.
  Future<String> _writeTempFile(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'pick_${DateTime.now().millisecondsSinceEpoch}_$name'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Sends [filePath], queueing it locally when the device is offline.
  ///
  /// Online: the file is chunk-uploaded and the message is posted immediately.
  /// Offline: a copy of the file is retained on disk, the message is written to
  /// SQLite with a "queued" state, and the outbox uploads and posts it the
  /// moment connectivity returns. Either way the attachment bytes are captured
  /// before this method returns, so nothing is lost if the app is killed or the
  /// picker is a temporary cache file.
  Future<void> _uploadAndSend({
    required String type,
    required String filePath,
    required String fileName,
    required String? mimeType,
    int? durationMs,
  }) async {
    // Compress before anything else touches the bytes. This runs before staging
    // so the staged copy, the resume journal and the upload all refer to the
    // same bytes - compressing afterwards would mean resuming against a file
    // whose contents no longer match the journal's key.
    String pathToUpload = filePath;
    String nameToUpload = fileName;
    String? mimeToUpload = mimeType;
    if (mounted) {
      setState(() {
        _sending = true;
        _sendingLabel = 'Compressingâ€¦';
        _sendingFraction = 0;
        _sendingEta = null;
      });
    }
    final prepared = await MediaCompressor().prepare(
      path: filePath,
      mimeType: mimeType ?? '',
      quality: _compressionQuality,
      isCancelled: () => !mounted,
    );
    if (!mounted) return;
    pathToUpload = prepared.path;
    if (prepared.compressed) {
      // The encoder always emits JPEG. Reusing the original name would leave a
      // file called `photo.png` that is actually JPEG data, which some
      // players and every downstream MIME guess get wrong.
      nameToUpload = _asJpegName(fileName);
      mimeToUpload = 'image/jpeg';
      setState(() {
        _sendingLabel =
            'Compressed ${formatBytes(prepared.outgoingBytes)} '
            '(was ${formatBytes(prepared.originalBytes)})';
      });
    }

    final stagedPath = await _stageOutgoingFile(pathToUpload, nameToUpload);
    if (!mounted) return;

    // The compressed copy in the OS temp directory is ours alone; drop it as
    // soon as the bytes are staged in app-owned storage.
    if (prepared.compressed) {
      unawaited(MediaCompressor.discard(prepared.path));
    }

    final attachment = Attachment(
      name: nameToUpload,
      mimeType: mimeToUpload,
      sizeBytes: await _sizeOf(stagedPath),
      localPath: stagedPath,
    );

    // The bubble is created FIRST, pointing at the staged local file and with
    // no upload id yet. The outbox owns upload from here.
    //
    // This ordering is the whole point: previously the file was uploaded to
    // completion before the message was created, so for a 300 MB video the
    // user saw nothing at all for minutes and then a bubble appeared fully
    // formed. Now the bubble appears immediately and carries a progress ring
    // for the entire transfer, which is what makes a large send feel like it is
    // doing something.
    //
    // It is also strictly more robust: the message is in the durable outbox
    // before the first byte leaves, so a crash or a kill mid-upload leaves a
    // queued message that resumes, rather than an upload with nothing to attach
    // it to.
    final service = await ref.read(mediaTransferServiceProvider.future);
    if (!mounted) return;

    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .sendMedia(type: type, durationMs: durationMs, attachment: attachment);
    if (!mounted) return;

    if (!_online) {
      _snack('No connection. Message queued and will send automatically.');
      if (mounted) setState(() => _sending = false);
      return;
    }

    setState(() {
      _sending = true;
      _sendingFraction = 0;
      _sendingEta = null;
      _sendSpeed.reset();
      if (_sendingLabel == null || !_sendingLabel!.startsWith('Compressed')) {
        _sendingLabel = 'Sending...';
      }
    });

    // Drive the upload through the service here rather than leaving it entirely
    // to the outbox, so the banner keeps showing speed and ETA. Both paths write
    // the same manifest onto the same message; whichever finishes first wins,
    // and the other is a no-op because the attachment already carries an
    // upload id by then.
    try {
      await service.send(
        conversationId: widget.conversationId,
        filePath: stagedPath,
        fileName: nameToUpload,
        mimeType: mimeToUpload,
        onProgress: (MediaTransferProgress p) {
          if (!mounted) return;
          final speed = _sendSpeed.update(p.bytesTransferred, DateTime.now());
          final total = p.totalBytes;
          final fraction = p.fraction;
          setState(() {
            _sendingFraction = fraction;
            _sendingLabel = [
              'Sending ${formatBytes(p.bytesTransferred)} of ${formatBytes(total)}',
              if (fraction != null) '${(fraction * 100).round()}%',
              if (speed > 1) '${formatBytes(speed.round())}/s',
            ].join(' • ');
            _sendingEta = _sendEtaLabel(p.bytesTransferred, total, speed);
          });
        },
      );

      // The manifest is attached to the already-sent message by the outbox
      // row it rewrites; nothing to post here. The bubble updates in place.
    } on MediaQuotaException catch (e) {
      // A quota refusal is a policy decision, not a transient failure, so it
      // gets the actual reason instead of a generic "try again".
      _snack(e.message);
    } on MediaTransferException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not attach \'$nameToUpload\'. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _sendingLabel = null;
          _sendingFraction = null;
        });
      }
    }
  }

  /// Copies the picked file into app-owned storage before it is referenced.
  ///
  /// `image_picker` and `file_picker` can both hand back a path in a temporary
  /// or provider cache that Android is free to reclaim at any moment. A queued
  /// message that points at one of those would silently lose its bytes, so the
  /// file is copied somewhere the app owns and never cleaned behind its back.
  Future<String> _stageOutgoingFile(String path, String name) async {
    final source = File(path);
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'outgoing_media'));
    await dir.create(recursive: true);
    final target = File(
      p.join(
        dir.path,
        '${DateTime.now().microsecondsSinceEpoch}_${_safeName(name)}',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^\w.\- ]'), '_');

  /// Rewrites a file name so its extension matches the JPEG bytes the encoder
  /// actually produced.
  ///
  /// The name is user-visible (it is what the recipient sees and what the
  /// gallery saves), and several players and MIME sniffers branch on the
  /// extension, so a `.heic` name carrying JPEG data is a real failure mode
  /// rather than a cosmetic one.
  static String _asJpegName(String name) {
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    return '$base.jpg';
  }

  /// Compression profile, resolved from the user's saved preference.
  ///
  /// Read at send time rather than cached in `initState` so a change in
  /// settings applies to the next send without needing a rebuild.
  CompressionQuality get _compressionQuality {
    final value = ref
        .read(settingsControllerProvider)
        .valueOrNull
        ?.mediaCompressionQuality;
    return switch (value) {
      'original' => CompressionQuality.original,
      'dataSaver' => CompressionQuality.dataSaver,
      _ => CompressionQuality.balanced,
    };
  }

  Future<int> _sizeOf(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  /// "2m 10s left", or null while the estimate is not yet trustworthy.
  ///
  /// Deliberately returns null on the first sample: a countdown derived from a
  /// single reading is a lie that the user watches fail.
  String? _sendEtaLabel(int transferred, int total, double bytesPerSecond) {
    if (bytesPerSecond < 1) return null;
    final remaining = total - transferred;
    if (remaining <= 0) return null;
    final seconds = remaining / bytesPerSecond;
    if (seconds.isNaN || seconds.isInfinite || seconds > 86400) return null;
    return '${formatDuration(Duration(milliseconds: (seconds * 1000).round()))} left';
  }

  /// Uploads and sends a finished voice recording.
  ///
  /// Receives the file rather than opening a recorder: the composer owns the
  /// recording lifecycle and hands over the result, which is what keeps the mic
  /// released before any upload starts.
  Future<void> _recordVoice(String path, int durationMs) async {
    if (!mounted) return;
    // Streamed from the recording's own file, never buffered.
    await _uploadAndSend(
      type: 'voice',
      filePath: path,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      mimeType: 'audio/mp4',
      durationMs: durationMs,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAttachSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Add attachment',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo from gallery'),
              subtitle: const Text('Pick one or more images'),
              onTap: () {
                Navigator.of(context).pop();
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Send a video'),
              onTap: () {
                Navigator.of(context).pop();
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('Send a file'),
              onTap: () {
                Navigator.of(context).pop();
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Send multiple files'),
              subtitle: const Text('Pick several files at once'),
              onTap: () {
                Navigator.of(context).pop();
                _pickMultipleFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Record a voice note'),
              onTap: () {
                Navigator.of(context).pop();
                // The composer owns the recording UI, so this entry point starts
                // the very same recording rather than opening a second UI. The
                // composer swaps its own input row once the controller reports
                // `isRecording`.
                unawaited(_voice.start());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.conversationId));
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedPeer = ref
        .watch(conversationPeerProvider(widget.conversationId))
        .valueOrNull;
    final peer = widget.initialPeer?.peer ?? resolvedPeer;
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final wallpaper = settings.chatWallpaper;

    return Scaffold(
      // Frosted so the scrolling transcript stays visible behind the header,
      // which is the one place in this app where content genuinely moves
      // underneath a surface.
      appBar: GlassAppBar(
        showBack: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        titleSpacing: 0,
        titleWidget: Row(
          children: [
            if (peer != null)
              GestureDetector(
                onTap: () => showProfileQuickView(
                  context,
                  ref,
                  profile: peer,
                  conversationId: widget.conversationId,
                ),
                child: UserAvatar(
                  profile: peer,
                  radius: 18,
                  online: state.peerPresence == 'online',
                  avatarUserId: peer.id,
                ),
              )
            else
              UserAvatar(profile: peer, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          peer?.displayName ?? 'Chat',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (peer?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(),
                      ],
                    ],
                  ),
                  Text(
                    _presenceLabel(state.peerPresence, state.peerLastSeenAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [const SizedBox(width: 8)],
      ),
      body: Container(
        decoration: wallpaper == 'gojo'
            ? const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=1000&auto=format&fit=crop',
                  ),
                  fit: BoxFit.cover,
                ),
              )
            : wallpaper == 'black'
            ? const BoxDecoration(color: Colors.black)
            : null,
        child: Column(
          children: [
            const OfflineBanner(),
            if (state.isTyping)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _TypingIndicator(),
                  ),
                ),
              ),
            Expanded(
              child: state.messages.isEmpty
                  ? (state.initialLoading
                        ? const Center(child: CircularProgressIndicator())
                        : const _EmptyChat())
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount:
                          state.messages.length +
                          (state.hasMoreHistory || state.loadingOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Reversed thread: index 0 is the newest message at the
                        // bottom; the trailing slot is the "loading earlier
                        // messages" affordance at the top (auto-triggered by
                        // scrolling up, WhatsApp/Messenger-style).
                        if (index == state.messages.length) {
                          return _LoadEarlier(loading: state.loadingOlder);
                        }
                        final originalIndex = state.messages.length - 1 - index;
                        final message = state.messages[originalIndex];
                        final previous = originalIndex > 0
                            ? state.messages[originalIndex - 1]
                            : null;
                        final next = originalIndex + 1 < state.messages.length
                            ? state.messages[originalIndex + 1]
                            : null;
                        // Resolve the reply target from the loaded window. A
                        // reply to something scrolled out of the local window
                        // simply renders without a quote rather than crashing.
                        final replyToId = message.replyToId;
                        final repliedTo = replyToId == null
                            ? null
                            : state.messages
                                  .where(
                                    (m) =>
                                        m.id == replyToId ||
                                        m.clientMessageId == replyToId,
                                  )
                                  .firstOrNull;
                        return GestureDetector(
                          onHorizontalDragEnd: (details) {
                            if ((details.primaryVelocity ?? 0) > 200) {
                              _startReply(message);
                            }
                          },
                          child: MessageBubble(
                          // Required, not cosmetic. The list is virtualised with
                          // `reverse: true`, so Flutter reuses State positionally
                          // and a bubble scrolled onto a different message kept
                          // the previous message's local file and player â€” showing
                          // the wrong voice note or video.
                          key: ValueKey(message.id),
                          message: message,
                          previous: previous,
                          next: next,
                          peer: peer,
                          myUserId: ref.watch(authStateProvider).user?.id,
                          onReact: (messageId, emoji) => ref
                              .read(
                                chatControllerProvider(
                                  widget.conversationId,
                                ).notifier,
                              )
                              .sendReaction(messageId: messageId, emoji: emoji),
                          onRetry:
                              message.localState == MessageLocalState.failed
                              ? () => ref
                                    .read(
                                      chatControllerProvider(
                                        widget.conversationId,
                                      ).notifier,
                                    )
                                    .retryFailed()
                              : null,
                          onReply: () => _startReply(message),
                          repliedTo: repliedTo,
                          // Editing is a sender-only, text-only affordance.
                          onEdit:
                              message.outgoing &&
                                  !message.isMedia &&
                                  (message.body?.isNotEmpty ?? false)
                              ? () => _startEdit(message)
                              : null,
                          onDeleteForMe: () => _confirmDeleteForMe(message),
                          // Offered for every message the user can see: "for
                          // everyone" is allowed for someone else's message inside
                          // the server's age window, and the server is the one
                          // that decides. Hiding it here would hide a capability
                          // that exists.
                          onDeleteForEveryone: () =>
                              _confirmDeleteForEveryone(message),
                        ));
                      },
                    ),
            ),
            // WhatsApp-style live transfer indicator: tapping it opens the full
            // sending/receiving list. It survives navigating away from this chat
            // because the tracker is process-wide.
            ActiveTransfersPill(tracker: ref.watch(transferTrackerProvider)),
            // A determinate progress bar replaces the bare spinner while a
            // large attachment streams up, with the size and time remaining so
            // a multi-gigabyte video never looks like a hang.
            if (_sending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmoothProgressBar(value: _sendingFraction, height: 4),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sendingLabel ?? 'Sendingâ€¦',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_sendingEta != null)
                          Text(
                            _sendingEta!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            _Composer(
              controller: _composer,
              focusNode: _composerFocus,
              voice: _voice,
              sending: _sending,
              onChanged: _onComposerChanged,
              onAttach: _openAttachSheet,
              onRecordVoice: _recordVoice,
              onSend: _send,
              replyingTo: _replyingTo,
              onCancelReply: _cancelReply,
              editing: _editing,
              onCancelEdit: _cancelEdit,
            ),
          ],
        ),
      ),
    );
  }

  String _presenceLabel(String presence, DateTime? lastSeen) {
    if (presence == 'online') return 'Online';
    if (presence == 'lastSeen' || presence == 'offline') {
      if (lastSeen != null) return 'Last seen ${_timeAgo(lastSeen)}';
      return 'Offline';
    }
    return 'Offline';
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.voice,
    required this.sending,
    required this.onChanged,
    required this.onAttach,
    required this.onRecordVoice,
    required this.onSend,
    this.replyingTo,
    this.onCancelReply,
    this.editing,
    this.onCancelEdit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Recording state, owned by the page.
  ///
  /// Page-owned rather than created here because the attach sheet also offers
  /// "record a voice note", and both entry points must drive the *same*
  /// recording. Disposal belongs to the page for the same reason.
  final VoiceRecorderController voice;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttach;
  final void Function(String path, int durationMs) onRecordVoice;
  final VoidCallback onSend;

  /// Message currently being replied to, shown as a quote above the field.
  final ChatMessage? replyingTo;

  final VoidCallback? onCancelReply;

  /// Message currently being edited. Rendered as a distinct banner so the
  /// composer is never ambiguous about whether it will reply or rewrite.
  final ChatMessage? editing;

  final VoidCallback? onCancelEdit;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    // Dismiss the keyboard first: leaving it up behind the recording bar gives
    // two competing input areas in the same corner of the screen.
    FocusScope.of(context).unfocus();
    // A refused permission or a mic the platform would not open leaves us in
    // text mode, which is where the user already was.
    await widget.voice.start();
    if (mounted) setState(() {});
  }

  Future<void> _cancelRecording() async {
    await widget.voice.cancel();
    if (mounted) setState(() {});
  }

  Future<void> _sendRecording() async {
    final recording = await widget.voice.finish();
    if (!mounted) return;
    setState(() {});
    if (recording == null) return;
    widget.onRecordVoice(recording.path, recording.durationMs);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.voice,
      builder: (context, _) {
        // Recording replaces the text field entirely. Both states come from one
        // source of truth each - the controller and the text field - so the icon
        // and the row can never disagree.
        final recording = widget.voice.isRecording;
        final hasText = !recording && widget.controller.text.trim().isNotEmpty;

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.editing != null)
                _EditBanner(
                  message: widget.editing!,
                  onCancel: widget.onCancelEdit,
                ),
              if (widget.replyingTo != null)
                _ReplyBanner(
                  message: widget.replyingTo!,
                  onCancel: widget.onCancelReply,
                ),
              AnimatedSize(
                duration: Motion.fast,
                curve: Motion.standard,
                alignment: Alignment.bottomCenter,
                child: recording
                    ? _RecordingBar(
                        elapsed: widget.voice.elapsed,
                        amplitudes: widget.voice.amplitudes,
                        paused: widget.voice.isPaused,
                        busy: widget.voice.isBusy,
                        onCancel: _cancelRecording,
                        onPause: widget.voice.togglePause,
                        onSend: _sendRecording,
                      )
                    : _textRow(context, hasText),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _textRow(BuildContext context, bool hasText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: widget.sending ? null : widget.onAttach,
            tooltip: 'Attach',
          ),
          Expanded(
            child: Shortcuts(
              // Enter sends, Shift+Enter inserts a newline.
              //
              // The field is `maxLines: 5` so the soft keyboard's action key is
              // "newline", which makes `onSubmitted` unreachable on Android and
              // iOS - it only fired for a single-line field. Handling the key
              // here makes it work everywhere. `SingleActivator` with no
              // modifiers does not match Shift+Enter, so newline still works.
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): _SendIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter): _SendIntent(),
              },
              child: Actions(
                actions: {
                  _SendIntent: CallbackAction<_SendIntent>(
                    onInvoke: (_) {
                      if (hasText && !widget.sending) widget.onSend();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) {
                    if (widget.controller.text.trim().isNotEmpty &&
                        !widget.sending) {
                      widget.onSend();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Message',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Dynamic WhatsApp-style toggle: Mic when empty, Send when has text.
          if (hasText)
            IconButton.filled(
              icon: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              onPressed: widget.sending ? null : widget.onSend,
              tooltip: 'Send',
            )
          else
            IconButton.filled(
              icon: const Icon(Icons.mic_rounded),
              onPressed: widget.sending ? null : _startRecording,
              tooltip: 'Record voice note',
            ),
        ],
      ),
    );
  }
}

/// The composer's recording state: timer, live meter, cancel, send.
///
/// Replaces the text field in place rather than floating over it, so the
/// controls the user needs are where their thumb already is.
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.elapsed,
    required this.amplitudes,
    required this.paused,
    required this.busy,
    required this.onCancel,
    required this.onPause,
    required this.onSend,
  });

  final Duration elapsed;
  final List<double> amplitudes;
  final bool paused;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onPause;
  final VoidCallback onSend;

  static String _clock(Duration d) {
    final seconds = d.inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Cancel discards the take and returns to the text field.
          IconButton(
            onPressed: busy ? null : onCancel,
            icon: Icon(Icons.delete_outline, color: error),
            tooltip: 'Discard recording',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      paused ? Icons.pause : Icons.mic,
                      size: 16,
                      color: paused
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _clock(elapsed),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (paused) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Paused',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                MicWaveform(amplitudes: amplitudes, height: 26),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onPause,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            tooltip: paused ? 'Resume' : 'Pause',
          ),
          // Send. The reason this control has to exist in the bar: with the
          // text field replaced there is no send button anywhere on screen, so
          // without it a finished recording has no way out.
          IconButton.filled(
            onPressed: busy ? null : onSend,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            tooltip: 'Send voice note',
          ),
        ],
      ),
    );
  }
}

/// The quoted message being replied to, shown above the composer.
///
/// Without this the reply target is invisible: the user taps "Reply" on a
/// message, the keyboard opens, and nothing tells them what they are answering,
/// so a mistap sends an unanchored message.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message, this.onCancel});

  final ChatMessage message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = message.body?.trim().isNotEmpty == true
        ? message.body!.trim()
        : switch (message.type) {
            'image' => '📷 Photo',
            'video' => '🎥 Video',
            'voice' => '🎤 Voice note',
            _ => '📎 Attachment',
          };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.outgoing ? 'Replying to you' : 'Replying',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
            tooltip: 'Cancel reply',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Composer banner shown while rewriting a message.
///
/// Deliberately a different colour and a different label from [_ReplyBanner]:
/// both modes use the same field, and a user who cannot tell which one is
/// active will send an edited message as a reply (or the reverse), which is
/// unrecoverable once sent.
class _EditBanner extends StatelessWidget {
  const _EditBanner({required this.message, this.onCancel});

  final ChatMessage message;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: theme.colorScheme.secondary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing message',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  message.body?.trim() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
            tooltip: 'Cancel edit',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Intent for the "Enter sends" shortcut.
///
/// A distinct type rather than reusing `VoidCallbackIntent` so it cannot
/// collide with any other Enter binding in the tree.
class _SendIntent extends Intent {
  const _SendIntent();
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text('Say hello!', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// Auto-refreshed "loading earlier history" affordance pinned to the top of a
/// reversed [ListView]: a spinner while a page is being fetched, otherwise an
/// invisible spacer that scrolling up (to max scroll extent) slips past.
class _LoadEarlier extends StatelessWidget {
  const _LoadEarlier({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading) return const SizedBox(height: 24);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Animated typing indicator with bouncing dots.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'typing',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final delay = index * 0.15;
                  final value = (_controller.value - delay).clamp(0.0, 1.0);
                  final scale = 0.5 + 0.5 * (1 - (value * 2 - 1).abs());
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
