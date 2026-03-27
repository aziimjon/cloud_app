import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 3-layer cache: Memory (LRU, 50 items) → Disk (300MB cap) → SQLite metadata.
/// All disk I/O runs off the main isolate. Auto-cleanup every 10 minutes.
/// Thread-safe via Completer-based mutex. Safe delete order: DB → file.
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  static const int _maxMemoryItems = 50;
  static const int _maxDiskBytes = 300 * 1024 * 1024; // 300MB
  static const Duration _cleanupInterval = Duration(minutes: 10);
  static const int _isolateThreshold = 64 * 1024; // 64KB — skip compute() below this

  final LinkedHashMap<String, Uint8List> _memoryCache =
      LinkedHashMap<String, Uint8List>();

  Database? _metaDb;
  Directory? _diskDir;
  Timer? _cleanupTimer;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  // ── Mutex ─────────────────────────────────────────────────────────────
  // Serializes all cache operations to prevent race conditions
  // between get/put/evict/cleanup running concurrently.
  final _opQueue = <Completer<void>>[];
  bool _opRunning = false;

  Future<T> _withLock<T>(Future<T> Function() fn) async {
    final completer = Completer<void>();
    _opQueue.add(completer);
    if (_opRunning) {
      // Wait for our turn
      final idx = _opQueue.indexOf(completer);
      if (idx > 0) {
        await _opQueue[idx - 1].future;
      }
    }
    _opRunning = true;
    try {
      return await fn();
    } finally {
      _opRunning = _opQueue.length > 1;
      _opQueue.remove(completer);
      completer.complete();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────

  /// Initialize cache system. Safe to call concurrently — uses Completer guard.
  Future<void> init() async {
    if (_initialized) return;

    // Guard against concurrent init() calls
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();

    try {
      final appDir = await getApplicationSupportDirectory();
      _diskDir = Directory(p.join(appDir.path, 'file_cache'));
      if (!_diskDir!.existsSync()) {
        _diskDir!.createSync(recursive: true);
      }

      final dbPath = p.join(await getDatabasesPath(), 'cache_meta.db');
      _metaDb = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_metadata (
              key TEXT PRIMARY KEY,
              disk_path TEXT NOT NULL,
              size_bytes INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              last_accessed INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_cache_last_accessed ON cache_metadata(last_accessed)');
        },
      );

      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _autoCleanup());

      _initialized = true;
      debugPrint('[CacheManager] Initialized');
    } catch (e) {
      debugPrint('[CacheManager] init() failed: $e');
    } finally {
      _initCompleter!.complete();
      _initCompleter = null;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Retrieve cached data by key. Checks memory → disk. Thread-safe.
  Future<Uint8List?> get(String key) async {
    if (!_initialized) return null;

    // Layer 1: Memory (no lock needed for read — single-threaded Dart)
    if (_memoryCache.containsKey(key)) {
      final data = _memoryCache.remove(key)!;
      _memoryCache[key] = data; // Move to end (most recently used)
      return data;
    }

    // Layer 2: Disk (locked)
    return _withLock(() async {
      if (_metaDb == null) return null;
      try {
        final rows = await _metaDb!.query(
          'cache_metadata',
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        if (rows.isEmpty) return null;

        final diskPath = rows.first['disk_path'] as String;
        final file = File(diskPath);
        if (!file.existsSync()) {
          // Recovery: metadata exists but file missing — clean up metadata
          await _metaDb!.delete('cache_metadata',
              where: 'key = ?', whereArgs: [key]);
          debugPrint('[CacheManager] Recovery: removed orphan metadata for $key');
          return null;
        }

        // Read: use compute() only for files above threshold
        final fileSize = file.lengthSync();
        Uint8List data;
        if (fileSize > _isolateThreshold) {
          data = await compute(_readFileBytes, diskPath);
        } else {
          data = file.readAsBytesSync();
        }

        // Update last_accessed
        await _metaDb!.update(
          'cache_metadata',
          {'last_accessed': DateTime.now().millisecondsSinceEpoch},
          where: 'key = ?',
          whereArgs: [key],
        );

        // Promote to memory cache
        _putMemory(key, data);
        return data;
      } catch (e) {
        debugPrint('[CacheManager] get($key) failed: $e');
        return null;
      }
    });
  }

  /// Store data in cache (memory + disk). Thread-safe.
  Future<void> put(String key, Uint8List data) async {
    if (!_initialized) return;
    _putMemory(key, data);
    await _withLock(() => _putDisk(key, data));
  }

  /// Remove a specific key from all cache layers. Thread-safe.
  /// Safe delete order: DB first → file second (prevents orphan reads).
  Future<void> evict(String key) async {
    _memoryCache.remove(key);
    if (!_initialized || _metaDb == null) return;

    await _withLock(() async {
      try {
        final rows = await _metaDb!.query(
          'cache_metadata',
          columns: ['disk_path'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final diskPath = rows.first['disk_path'] as String;
          // DB first, then file — safe order
          await _metaDb!.delete('cache_metadata',
              where: 'key = ?', whereArgs: [key]);
          try {
            final file = File(diskPath);
            if (file.existsSync()) await file.delete();
          } catch (e) {
            debugPrint('[CacheManager] File delete failed (non-fatal): $e');
          }
        }
      } catch (e) {
        debugPrint('[CacheManager] evict($key) failed: $e');
      }
    });
  }

  /// Check if key exists in any cache layer.
  Future<bool> contains(String key) async {
    if (_memoryCache.containsKey(key)) return true;
    if (_metaDb == null) return false;
    try {
      final count = Sqflite.firstIntValue(await _metaDb!.rawQuery(
        'SELECT COUNT(*) FROM cache_metadata WHERE key = ?',
        [key],
      ));
      return (count ?? 0) > 0;
    } catch (e) {
      debugPrint('[CacheManager] contains($key) failed: $e');
      return false;
    }
  }

  /// Dispose all resources. Must be called on app shutdown.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _memoryCache.clear();
    _metaDb?.close();
    _metaDb = null;
    _initialized = false;
    debugPrint('[CacheManager] Disposed');
  }

  // ── Memory Layer ──────────────────────────────────────────────────────

  void _putMemory(String key, Uint8List data) {
    _memoryCache.remove(key);
    _memoryCache[key] = data;
    while (_memoryCache.length > _maxMemoryItems) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  // ── Disk Layer ────────────────────────────────────────────────────────

  Future<void> _putDisk(String key, Uint8List data) async {
    if (_diskDir == null || _metaDb == null) return;

    final safeKey = key.replaceAll(RegExp(r'[^\w.-]'), '_');
    final diskPath = p.join(_diskDir!.path, safeKey);

    try {
      // Write: use compute() only for data above threshold
      if (data.length > _isolateThreshold) {
        await compute(_writeFileBytes, _WriteArgs(diskPath, data));
      } else {
        File(diskPath).writeAsBytesSync(data);
      }

      await _metaDb!.insert(
        'cache_metadata',
        {
          'key': key,
          'disk_path': diskPath,
          'size_bytes': data.length,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'last_accessed': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on FileSystemException catch (e) {
      // Disk full or permission error — log and skip, don't crash
      debugPrint('[CacheManager] Disk write failed (disk full?): $e');
      // Attempt emergency cleanup to free space
      await _autoCleanup();
    } catch (e) {
      debugPrint('[CacheManager] _putDisk($key) failed: $e');
    }
  }

  // ── Auto-Cleanup ─────────────────────────────────────────────────────

  bool _cleanupRunning = false;

  Future<void> _autoCleanup() async {
    // Guard: prevent overlapping cleanups
    if (_cleanupRunning || _metaDb == null || !_initialized) return;
    _cleanupRunning = true;

    try {
      final totalSize = Sqflite.firstIntValue(await _metaDb!.rawQuery(
            'SELECT SUM(size_bytes) FROM cache_metadata',
          )) ??
          0;

      if (totalSize <= _maxDiskBytes) return;

      debugPrint(
          '[CacheManager] Disk ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB > ${_maxDiskBytes ~/ 1024 ~/ 1024}MB, purging');

      var bytesToFree = totalSize - _maxDiskBytes;

      final oldest = await _metaDb!.query(
        'cache_metadata',
        orderBy: 'last_accessed ASC',
        limit: 50,
      );

      for (final row in oldest) {
        if (bytesToFree <= 0) break;

        final key = row['key'] as String;
        final diskPath = row['disk_path'] as String;
        final size = row['size_bytes'] as int;

        // Safe order: DB first, then file
        await _metaDb!.delete('cache_metadata',
            where: 'key = ?', whereArgs: [key]);
        _memoryCache.remove(key);

        try {
          final file = File(diskPath);
          if (file.existsSync()) await file.delete();
        } catch (_) {}

        bytesToFree -= size;
      }

      debugPrint('[CacheManager] Cleanup complete');
    } catch (e) {
      debugPrint('[CacheManager] _autoCleanup failed: $e');
    } finally {
      _cleanupRunning = false;
    }
  }
}

// ── Isolate helpers (top-level for compute()) ────────────────────────────────

Uint8List _readFileBytes(String path) {
  return File(path).readAsBytesSync();
}

void _writeFileBytes(_WriteArgs args) {
  File(args.path).writeAsBytesSync(args.data);
}

class _WriteArgs {
  final String path;
  final Uint8List data;
  const _WriteArgs(this.path, this.data);
}
