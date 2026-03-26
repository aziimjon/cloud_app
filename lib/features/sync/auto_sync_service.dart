import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import 'data/gallery_service.dart';
import 'data/sync_queue_db.dart';
import 'data/tus_sync_uploader.dart';
import 'domain/media_scanner.dart';

class SyncProgress {
  final int pending;
  final int uploading;
  final int done;
  final int failed;
  final double currentFileProgress;

  const SyncProgress({
    this.pending = 0,
    this.uploading = 0,
    this.done = 0,
    this.failed = 0,
    this.currentFileProgress = 0.0,
  });
}

class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  static const String _kColdStartKey = 'sync_cold_start_done';
  static const String _kAutoSyncEnabledKey = 'auto_sync_enabled';

  final SyncQueueDb _db = SyncQueueDb();
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  Stream<SyncProgress> get progressStream => _progressController.stream;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Call once at app startup, after WidgetsFlutterBinding.ensureInitialized().
  Future<void> initialize() async {
    await _db.init();

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[AutoSync] No auth token found, skipping initialize');
      return;
    }

    final baseUrl = AppConfig.instance.baseUrl;
    final galleryService = GalleryService(baseUrl: baseUrl, token: token);

    Set<String> uploadedKeys = {};
    final prefs = await SharedPreferences.getInstance();
    final coldStartDone = prefs.getBool(_kColdStartKey) ?? false;

    if (!coldStartDone) {
      try {
        uploadedKeys = await galleryService.getUploadedFileKeys();
        debugPrint(
            '[AutoSync] Cold start: loaded ${uploadedKeys.length} keys from server');
      } catch (e) {
        debugPrint('[AutoSync] Cold start gallery fetch failed: $e');
        // Continue with empty set — deduplication will rely on local DB only
      }
    }

    final scanner = MediaScanner(db: _db, uploadedKeys: uploadedKeys);
    final newItems = await scanner.scanAndEnqueue();
    debugPrint('[AutoSync] Scanned: $newItems new items enqueued');

    if (!coldStartDone) {
      await prefs.setBool(_kColdStartKey, true);
    }

    await _emitProgress();
  }

  /// Starts processing the pending upload queue.
  Future<void> startSync() async {
    if (_isRunning) return;

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[AutoSync] Cannot start sync: no auth token');
      return;
    }

    _isRunning = true;
    final uploader = TusSyncUploader(authToken: token);

    try {
      while (_isRunning) {
        final tasks = await _db.getPending(limit: 3);
        if (tasks.isEmpty) {
          debugPrint('[AutoSync] No pending tasks, sync complete');
          break;
        }

        for (final task in tasks) {
          if (!_isRunning) break;

          if (task.id == null) continue;
          await _db.markUploading(task.id!);
          await _emitProgress(currentProgress: 0.0);

          try {
            final serverUuid = await uploader.upload(
              task,
              onProgress: (progress) {
                _emitProgressSync(currentProgress: progress);
              },
            );
            await _db.markDone(task.id!, serverUuid);
            debugPrint('[AutoSync] Uploaded: ${task.fileName} → $serverUuid');
          } on TusUploadException catch (e) {
            await _db.markFailed(task.id!);
            debugPrint('[AutoSync] Upload failed: ${task.fileName} — $e');
          }

          await _emitProgress();
        }
      }
    } finally {
      _isRunning = false;
      await _emitProgress();
    }
  }

  /// Stops the sync loop after the current file finishes.
  Future<void> stopSync() async {
    _isRunning = false;
    debugPrint('[AutoSync] Sync stopped');
  }

  /// Clears the sync queue and cold-start flag (call on logout).
  Future<void> onLogout() async {
    _isRunning = false;
    await _db.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kColdStartKey);
    debugPrint('[AutoSync] Logout: queue cleared');
  }

  /// Checks if auto-sync is currently enabled in preferences.
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoSyncEnabledKey) ?? false;
  }

  /// Sets the auto-sync enabled preference.
  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSyncEnabledKey, enabled);
  }

  Future<void> _emitProgress({double currentProgress = 0.0}) async {
    final counts = await _db.getStatusCounts();
    _progressController.add(SyncProgress(
      pending: counts['pending'] ?? 0,
      uploading: counts['uploading'] ?? 0,
      done: counts['done'] ?? 0,
      failed: counts['failed'] ?? 0,
      currentFileProgress: currentProgress,
    ));
  }

  void _emitProgressSync({double currentProgress = 0.0}) {
    // Lightweight emit without DB query — only updates progress bar
    _progressController.add(SyncProgress(currentFileProgress: currentProgress));
  }
}
