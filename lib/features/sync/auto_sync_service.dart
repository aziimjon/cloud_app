import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import 'data/gallery_service.dart';
import 'data/sync_queue_db.dart';
import 'data/tus_sync_uploader.dart';
import 'domain/media_scanner.dart';
import '../home/data/home_repository.dart';

class SyncProgress {
  final int pending;
  final int uploading;
  final int done;
  final int failed;
  final double currentFileProgress;
  final String? currentFileName;
  final int totalInBatch;

  const SyncProgress({
    this.pending = 0,
    this.uploading = 0,
    this.done = 0,
    this.failed = 0,
    this.currentFileProgress = 0.0,
    this.currentFileName,
    this.totalInBatch = 0,
  });
}

class AutoSyncService {

  Future<void> startAutoSync() async {
    await startSync();
  }

  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  static const String _kColdStartKey = 'sync_cold_start_done';
  static const String _kAutoSyncEnabledKey = 'auto_sync_enabled';
  static const String _kSyncFolderUuidKey = 'sync_folder_uuid';
  static const String _kSyncFolderPinnedKey = 'sync_folder_pinned';

  final SyncQueueDb _db = SyncQueueDb();
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  Stream<SyncProgress> get progressStream => _progressController.stream;
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  int _syncSessionId = 0;

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

    // Selective sync: only enqueue selected files if enabled
    Set<String>? selectedIds;
    final selectiveOn = prefs.getBool('auto_sync_selected_only') ?? false;
    if (selectiveOn) {
      final list = prefs.getStringList('selected_files') ?? [];
      // Validate: remove empty strings, treat empty set as null (full gallery)
      final cleaned = list.where((id) => id.trim().isNotEmpty).toSet();
      if (cleaned.isNotEmpty) {
        selectedIds = cleaned;
        debugPrint('[AutoSync] Selective sync ON: ${selectedIds.length} valid items');
      } else {
        debugPrint('[AutoSync] Selective sync ON but no valid IDs — falling back to full gallery');
      }
    }

    final scanner = MediaScanner(
      db: _db,
      uploadedKeys: uploadedKeys,
      selectedLocalIds: selectedIds,
    );
    final newItems = await scanner.scanAndEnqueue();
    debugPrint('[AutoSync] Scanned: $newItems new items enqueued');

    if (!coldStartDone) {
      await prefs.setBool(_kColdStartKey, true);
    }

    await _emitProgress();
  }

  /// Ensures the "📱 Sync" folder exists on the server.
  /// On first run creates it, pins it, saves UUID.
  /// On subsequent runs verifies server-side existence.
  Future<String?> _ensureSyncFolder() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we have a saved UUID
    final existing = prefs.getString(_kSyncFolderUuidKey);
    if (existing != null && existing.isNotEmpty) {
      // Verify folder still exists on server
      try {
        final repo = HomeRepository();
        final exists = await repo.folderExists(existing);
        if (exists) {
          debugPrint('[Sync] Sync folder verified on server: $existing');
          // Ensure it is pinned
          await _ensurePinned(existing);
          return existing;
        }
        // Folder was deleted on server — clear and recreate
        debugPrint('[Sync] Sync folder $existing missing on server, recreating');
        await prefs.remove(_kSyncFolderUuidKey);
        await prefs.remove(_kSyncFolderPinnedKey);
      } catch (e) {
        debugPrint('[Sync] Could not verify folder existence: $e');
        // If we can't verify, assume it exists and try to use it
        return existing;
      }
    }

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    final dio = Dio(BaseOptions(baseUrl: AppConfig.instance.baseUrl));

    try {
      // Step 1: Create folder
      final createResponse = await dio.post(
        '/content/folder/',
        data: {'name': '📱 Sync'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final folderUuid = createResponse.data['id'].toString();
      debugPrint('[Sync] Sync folder created: $folderUuid');

      // Step 2: Pin folder
      await _ensurePinned(folderUuid);

      // Step 3: Save UUID
      await prefs.setString(_kSyncFolderUuidKey, folderUuid);
      return folderUuid;
    } catch (e) {
      debugPrint('[Sync] _ensureSyncFolder failed: $e');
      return null;
    }
  }

  /// Ensures the sync folder is pinned. Silently ignores errors (e.g. already pinned).
  Future<void> _ensurePinned(String folderUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPinned = prefs.getBool(_kSyncFolderPinnedKey) ?? false;
    if (alreadyPinned) return;

    final token = await SecureStorage.getAccessToken();
    if (token == null) return;

    try {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.instance.baseUrl));
      await dio.post(
        '/content/pinned-folders/',
        data: {'folder': folderUuid},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await prefs.setBool(_kSyncFolderPinnedKey, true);
      debugPrint('[Sync] Sync folder pinned: $folderUuid');
    } catch (e) {
      debugPrint('[Sync] Pin attempt (non-critical): $e');
    }
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
    _syncSessionId++;
    final sessionId = _syncSessionId;
    _batchDone = 0;
    _batchFailed = 0;
    _totalInBatch = 0;
    _currentFileName = null;

    try {
      // Step 1: Ensure Sync folder exists and is pinned
      final syncFolderUuid = await _ensureSyncFolder();
      debugPrint('[Sync] Session $sessionId using folder: $syncFolderUuid');

      if (syncFolderUuid == null) {
        debugPrint('[Sync][ERROR] Could not create/find Sync folder. Aborting.');
        return;
      }

      final galleryService = GalleryService(
        baseUrl: AppConfig.instance.baseUrl,
        token: token,
      );
      final uploader = TusSyncUploader(authToken: token);

      while (_isRunning && sessionId == _syncSessionId) {
        // Get pending tasks sorted oldest first
        final tasks = await _db.getPendingOldestFirst(limit: 10);
        if (tasks.isEmpty) {
          debugPrint('[Sync] No pending tasks, sync complete');
          break;
        }

        _totalInBatch = tasks.length;

        // Step 2: Check duplicates in batch (fail-safe: on error, upload all)
        Map<String, bool> duplicateMap;
        try {
          duplicateMap = await galleryService.checkDuplicates(tasks);
        } catch (e) {
          debugPrint('[Sync] Duplicate check failed (uploading all): $e');
          duplicateMap = {};
        }

        for (final task in tasks) {
          if (!_isRunning || sessionId != _syncSessionId) break;
          if (task.id == null) continue;

          // Step 3: Skip duplicates
          final isDuplicate = duplicateMap[task.localId] ?? false;
          if (isDuplicate) {
            await _db.markDone(task.id!, 'duplicate_skipped');
            _batchDone++;
            debugPrint('[Sync] Skipped duplicate: ${task.fileName}');
            await _emitProgress();
            continue;
          }

          // Step 4: Verify file still exists on disk before upload
          final file = File(task.filePath);
          if (!file.existsSync()) {
            await _db.markFailed(task.id!);
            _batchFailed++;
            debugPrint('[Sync] File missing, skipped: ${task.filePath}');
            await _emitProgress();
            continue;
          }

          // Step 5: Upload new file INTO sync folder
          _currentFileName = task.fileName;
          await _db.markUploading(task.id!);
          await _emitProgress(currentProgress: 0.0);

          try {
            final serverUuid = await uploader.upload(
              task,
              folderId: syncFolderUuid,
              onProgress: (progress) {
                _emitProgressSync(currentProgress: progress);
              },
            );
            await _db.markDone(task.id!, serverUuid);
            _batchDone++;
            debugPrint('[Sync] Uploaded: ${task.fileName} → $serverUuid');
          } on TusUploadException catch (e) {
            await _db.markFailed(task.id!);
            _batchFailed++;
            debugPrint('[Sync][ERROR] Upload failed: ${task.fileName} — $e');
          } catch (e) {
            // Catch any unexpected error to prevent batch abort
            await _db.markFailed(task.id!);
            _batchFailed++;
            debugPrint('[Sync][ERROR] Unexpected: ${task.fileName} — $e');
          }

          await _emitProgress();
        }
      }
    } finally {
      _isRunning = false;
      _currentFileName = null;
      await _emitProgress();
    }
  }

  /// Stops the sync loop after the current file finishes.
  Future<void> stopSync() async {
    _isRunning = false;
    _syncSessionId++; // Invalidate current session
    debugPrint('[AutoSync] Sync stopped (session invalidated)');
  }

  /// Clears the sync queue and cold-start flag (call on logout).
  Future<void> onLogout() async {
    _isRunning = false;
    await _db.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kColdStartKey);
    await prefs.remove(_kSyncFolderUuidKey);
    await prefs.remove(_kSyncFolderPinnedKey);
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

  String? _currentFileName;
  int _batchDone = 0;
  int _batchFailed = 0;
  int _totalInBatch = 0;

  Future<void> _emitProgress({double currentProgress = 0.0}) async {
    final counts = await _db.getStatusCounts();
    _progressController.add(SyncProgress(
      pending: counts['pending'] ?? 0,
      uploading: counts['uploading'] ?? 0,
      done: (counts['done'] ?? 0) + _batchDone,
      failed: (counts['failed'] ?? 0) + _batchFailed,
      currentFileProgress: currentProgress,
      currentFileName: _currentFileName,
      totalInBatch: _totalInBatch,
    ));
  }

  void _emitProgressSync({double currentProgress = 0.0}) {
    _progressController.add(SyncProgress(
      currentFileProgress: currentProgress,
      currentFileName: _currentFileName,
      totalInBatch: _totalInBatch,
    ));
  }
}

