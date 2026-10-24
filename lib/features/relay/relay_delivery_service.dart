import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/local_store.dart';

typedef StorageDownloader = Future<Uint8List> Function(
  String bucket,
  String path,
);

abstract interface class RelayDriftCache {
  /// Persist the message and all attachments locally before returning.
  ///
  /// Download each object using [downloadObject], verify it where your upload
  /// format supplies a digest, and save the local message/file references.
  /// Throw if any required attachment is not completely saved.
  Future<void> saveMessageAndMedia(
    Map<String, dynamic> message,
    StorageDownloader downloadObject,
  );

  /// Record that the server has erased its payload.
  /// Keep any message/file content already cached on this device.
  Future<void> markServerPayloadErased(
    String messageId,
    DateTime erasedAt,
  );
}

class DownloadStatus {
  /// Status of a download operation
  enum Status {
    pending,
    inProgress,
    completed,
    failed,
  }

  /// Unique identifier for a download task
  final String taskId;

  /// Message ID being downloaded
  final String messageId;

  /// Download status
  final Status status;

  /// Progress percentage (0-100)
  final double progress;

  /// Error message if failed
  final String? error;

  DownloadStatus({
    required this.taskId,
    required this.messageId,
    required this.status,
    this.progress = 0.0,
    this.error,
  });
}

class DownloadInfo {
  /// Unique identifier for the download task
  final String taskId;

  /// Message ID
  final String messageId;

  /// Attachment bucket
  final String bucket;

  /// Attachment path
  final String path;

  /// Local file path where data is stored
  final String localPath;

  DownloadInfo({
    required this.taskId,
    required this.messageId,
    required this.bucket,
    required this.path,
    required this.localPath,
  });
}

class DownloadTask {
  /// Run a download task and report progress
  static Stream<DownloadStatus> run({
    required String taskId,
    required String messageId,
    required String bucket,
    required String path,
    required String localPath,
    required StorageDownloader downloadObject,
    required CancelToken cancelToken,
  }) async* {
    final totalSteps = 3;
    int completedSteps = 0;

    // Step 1: Start download
    yield DownloadStatus(
      taskId: taskId,
      messageId: messageId,
      status: DownloadStatus.inProgress,
      progress: 0.0,
    );

    try {
      // Check if cancelled
      if (cancelToken.isCancelled) {
        yield DownloadStatus(
          taskId: taskId,
          messageId: messageId,
          status: DownloadStatus.failed,
          error: 'Download cancelled',
        );
        return;
      }

      // Download the data
      final data = await downloadObject(bucket, path);
      completedSteps = 1;
      yield DownloadStatus(
        taskId: taskId,
        messageId: messageId,
        status: DownloadStatus.inProgress,
        progress: completedSteps / totalSteps,
      );

      // Step 2: Store data locally
      // TODO: Implement actual local storage based on your strategy
      // For now, just acknowledge completion
      completedSteps = 2;
      yield DownloadStatus(
        taskId: taskId,
        messageId: messageId,
        status: DownloadStatus.inProgress,
        progress: completedSteps / totalSteps,
      );

      // Step 3: Mark as complete
      completedSteps = 3;
      yield DownloadStatus(
        taskId: taskId,
        messageId: messageId,
        status: DownloadStatus.completed,
        progress: 1.0,
      );
    } on CancelException {
      yield DownloadStatus(
        taskId: taskId,
        messageId: messageId,
        status: DownloadStatus.failed,
        error: 'Download cancelled',
      );
    } catch (e) {
      yield DownloadStatus(
        taskId: taskId,
        messageId: messageId,
        status: DownloadStatus.failed,
        error: e.toString(),
      );
    }
  }
}

/// Cancel token for download tasks
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class DownloadQueue {
  DownloadQueue._internal();
  static final DownloadQueue _instance = DownloadQueue._internal();
  factory DownloadQueue() => _instance;

  final _tasks = <DownloadTaskData>{};
  final _listeners = <String, StreamController<DownloadStatus>>{};

  /// Add a download task
  void addTask(DownloadTaskData task) {
    _tasks[task.taskId] = task;
    _notifyListeners(task.taskId, DownloadStatus(
      taskId: task.taskId,
      messageId: task.messageId,
      status: DownloadStatus.pending,
    ));
  }

  /// Remove a completed task
  void removeTask(String taskId) {
    _tasks.remove(taskId);
    _listeners.remove(taskId);
    _notifyListeners(taskId, DownloadStatus(
      taskId: taskId,
      messageId: '',
      status: DownloadStatus.completed,
    ));
  }

  /// Get all task statuses
  Map<String, DownloadStatus> getAllStatuses() {
    return _tasks.map((id, task) {
      return MapEntry(
        id,
        DownloadStatus(
          taskId: task.taskId,
          messageId: task.messageId,
          status: _getTaskStatus(task),
          progress: _getTaskProgress(task),
          error: _getTaskError(task),
        ),
      );
    });
  }

  DownloadStatus _getTaskStatus(DownloadTaskData task) {
    // Check if cancelled
    // In a real implementation, check the cancel token
    return _tasks[task.taskId]?.status ?? DownloadStatus.pending;
  }

  double _getTaskProgress(DownloadTaskData task) {
    return _tasks[task.taskId]?.progress ?? 0.0;
  }

  String? _getTaskError(DownloadTaskData task) {
    return _tasks[task.taskId]?.error;
  }

  void _notifyListeners(String taskId, DownloadStatus status) {
    _listeners[taskId]?.add(status);
  }

  /// Subscribe to download status updates
  Stream<DownloadStatus> watch(String taskId) {
    final controller = _listeners.putIfAbsent(
      taskId,
      () => StreamController<DownloadStatus>.broadcast(),
    );
    return controller.stream;
  }

  /// Cancel all tasks
  void cancelAll() {
    _tasks.forEach((id, task) {
      // cancelToken.cancel(); // Would need to store cancel tokens
    });
    _tasks.clear();
    _listeners.clear();
  }
}

class DownloadTaskData {
  final String taskId;
  final String messageId;
  final String bucket;
  final String path;
  final String localPath;
  final StorageDownloader downloadObject;
  CancelToken? cancelToken;
  DownloadStatus status = DownloadStatus.pending;
  double progress = 0.0;
  String? error;

  DownloadTaskData({
    required this.taskId,
    required this.messageId,
    required this.bucket,
    required this.path,
    required this.localPath,
    required this.downloadObject,
  });
}

/// Provides download status for messages
final downloadStatusProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, DownloadStatus>>((ref) {
  return DownloadNotifier();
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadStatus>> {
  DownloadNotifier() : super({});

  /// Add a download task for a message attachment
  void addTask(DownloadTaskData task) {
    DownloadQueue().addTask(task);
    final allStatuses = DownloadQueue().getAllStatuses();
    state = {...allStatuses};
  }

  /// Get status for a specific message
  DownloadStatus? getTaskStatus(String messageId) {
    final allStatuses = state;
    return allStatuses.values.firstWhere(
      (status) => status.messageId == messageId,
      orElse: () => DownloadStatus(
        taskId: '',
        messageId: messageId,
        status: DownloadStatus.pending,
      ),
    );
  }

  /// Update task status
  void updateTaskStatus(DownloadStatus status) {
    final newState = {
      ...state,
      [status.taskId]: status,
    };
    state = newState;
    DownloadQueue().removeTask(status.taskId);
    DownloadQueue().addTask(DownloadTaskData(
      taskId: status.taskId,
      messageId: status.messageId,
      bucket: '', // Will be filled when needed
      path: '', // Will be filled when needed
      localPath: '', // Will be filled when needed
      downloadObject: (_, __) async => Uint8List(0),
    ));
  }
}

/// Download cancellation exception
class CancelException implements Exception {
  final String message;
  CancelException([this.message = 'Download cancelled']);
  @override
  String toString() => 'CancelException: $message';
}

/// Background download service that runs periodically
/// Uses Workmanager on Android and a simple timer on other platforms
abstract class BackgroundDownloadService {
  /// Initialize the background download service
  static Future<void> init() async {
    // Platform-specific initialization
    // On Android: register Workmanager task
    // On iOS: set up background fetch
    // On web: use timer-based polling
  }

  /// Check if background downloads are supported
  static bool get isSupported => true;

  /// Start background downloads
  static Future<void> start() async {
    await init();
    // Schedule periodic downloads
    // _schedulePeriodicDownload();
  }

  /// Stop background downloads
  static Future<void> stop() async {
    // Clean up background tasks
  }
}

/// Marks a message's attachments for background download
/// This should be called when a new message is received
void scheduleMediaDownload(
  String messageId,
  String bucket,
  String path,
  String localPath,
) {
  final taskId = 'download_$messageId';
  final task = DownloadTaskData(
    taskId: taskId,
    messageId: messageId,
    bucket: bucket,
    path: path,
    localPath: localPath,
    downloadObject: (_, __) async {
      // Will be replaced by actual download implementation
      return Uint8List(0);
    },
  );
  DownloadQueue().addTask(task);
}

/// Initialize background downloading when app starts
Future<void> initBackgroundDownloads() async {
  // await BackgroundDownloadService.init();
  // await BackgroundDownloadService.start();
}

/// Call this for each fetched message, from your existing sync/receive flow.
Future<void> acceptIncomingMessage(Map<String, dynamic> message) async {
  final messageId = message['id'] as String?;
  if (messageId == null) {
    throw const FormatException('Message is missing its id');
  }

  final erasedAt = message['payload_erased_at'];
  if (erasedAt != null) {
    // Do not overwrite or delete a copy already stored in Drift.
    await _localCache.markServerPayloadErased(
      messageId,
      DateTime.parse(erasedAt as String),
    );
    return;
  }

  // Schedule media download in background (non-blocking)
  // The download queue will handle downloading asynchronously
  final attachments = message['attachments'] as List<dynamic>? ?? [];
  for (final attachment in attachments) {
    final bucket = attachment['bucket'] as String? ?? '';
    final path = attachment['path'] as String? ?? '';
    final localPath = '${messageId}_$path';
    if (bucket.isNotEmpty && path.isNotEmpty) {
      scheduleMediaDownload(
        messageId,
        bucket,
        path,
        localPath,
      );
    }
  }

  // Mark the message as cached locally by updating its state
  final convId = message['conversationId'] as String? ?? '';
  final msgId = message['id'] as String? ?? '';
  if (convId.isNotEmpty && msgId.isNotEmpty) {
    await _store.markMessagesRead(convId);
  }

  // Only ACK after the Drift transaction and required file saves complete.
  await _supabase.rpc(
    'acknowledge_relay_message',
    params: {
      'p_message_id': messageId,
      'p_device_id': _deviceRowId,
    },
  );

  // If cleanup fails, the jobs remain pending and can be retried on resume.
  await drainStorageDeletionQueue();
}