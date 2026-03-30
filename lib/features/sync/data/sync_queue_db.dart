import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'sync_task.dart';

class SyncQueueDb {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'sync_queue.db');
      _db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              local_id TEXT UNIQUE NOT NULL,
              file_path TEXT NOT NULL,
              file_name TEXT NOT NULL,
              file_size INTEGER NOT NULL,
              mime_type TEXT NOT NULL,
              sha256 TEXT,
              session_id TEXT,
              status TEXT NOT NULL DEFAULT 'pending',
              retry_count INTEGER NOT NULL DEFAULT 0,
              server_uuid TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE sync_queue ADD COLUMN session_id TEXT');
            debugPrint('[SyncQueueDb] Migrated to v2: added session_id column');
          }
        },
      );
      debugPrint('[SyncQueueDb] Database initialized');
    } catch (e) {
      debugPrint('[SyncQueueDb] Failed to initialize database: $e');
      rethrow;
    }
  }

  Database get _database {
    if (_db == null) throw StateError('SyncQueueDb not initialized. Call init() first.');
    return _db!;
  }

  Future<void> insertOrIgnore(SyncTask task) async {
    try {
      await _database.insert(
        'sync_queue',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      debugPrint('[SyncQueueDb] insertOrIgnore failed: $e');
    }
  }

  Future<List<SyncTask>> getPending({int limit = 10}) async {
    try {
      final rows = await _database.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      return rows.map((r) => SyncTask.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[SyncQueueDb] getPending failed: $e');
      return [];
    }
  }

  /// Returns pending tasks sorted by created_at ASC (oldest first).
  /// Mirrors Google Photos upload order.
  Future<List<SyncTask>> getPendingOldestFirst({int limit = 10}) async {
    try {
      final rows = await _database.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      return rows.map((r) => SyncTask.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[SyncQueueDb] getPendingOldestFirst failed: $e');
      return [];
    }
  }

  Future<void> markUploading(int id) async {
    try {
      await _database.update(
        'sync_queue',
        {
          'status': SyncStatus.uploading.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[SyncQueueDb] markUploading failed: $e');
    }
  }

  Future<void> markDone(int id, String serverUuid) async {
    try {
      await _database.update(
        'sync_queue',
        {
          'status': SyncStatus.done.name,
          'server_uuid': serverUuid,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[SyncQueueDb] markDone failed: $e');
    }
  }

  Future<void> markFailed(int id) async {
    try {
      await _database.update(
        'sync_queue',
        {
          'status': SyncStatus.failed.name,
          'retry_count': Sqflite.firstIntValue(await _database.rawQuery(
                'SELECT retry_count FROM sync_queue WHERE id = ?',
                [id],
              )) ??
              0 + 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[SyncQueueDb] markFailed failed: $e');
    }
  }

  Future<bool> isDoneByHash(String sha256) async {
    try {
      final result = await _database.query(
        'sync_queue',
        where: 'sha256 = ? AND status = ?',
        whereArgs: [sha256, SyncStatus.done.name],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('[SyncQueueDb] isDoneByHash failed: $e');
      return false;
    }
  }

  Future<bool> exists(String localId) async {
    try {
      final result = await _database.query(
        'sync_queue',
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('[SyncQueueDb] exists failed: $e');
      return false;
    }
  }

  Future<Map<String, int>> getStatusCounts() async {
    try {
      final counts = <String, int>{
        'pending': 0,
        'uploading': 0,
        'done': 0,
        'failed': 0,
      };
      final rows = await _database.rawQuery(
        'SELECT status, COUNT(*) as cnt FROM sync_queue GROUP BY status',
      );
      for (final row in rows) {
        final status = row['status'] as String;
        final cnt = row['cnt'] as int;
        counts[status] = cnt;
      }
      return counts;
    } catch (e) {
      debugPrint('[SyncQueueDb] getStatusCounts failed: $e');
      return {'pending': 0, 'uploading': 0, 'done': 0, 'failed': 0};
    }
  }

  /// Count tasks by status. Pass null status to count ALL tasks.
  /// If sessionId is provided, filters by that session only.
  /// If sessionId is null, counts across all sessions (backward compat).
  Future<int> countByStatus(String? status, {String? sessionId}) async {
    try {
      final where = <String>[];
      final args = <dynamic>[];
      if (status != null) {
        where.add('status = ?');
        args.add(status);
      }
      if (sessionId != null) {
        where.add('session_id = ?');
        args.add(sessionId);
      }
      final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
      final result = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue $whereClause',
        args,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('[SyncQueueDb] countByStatus failed: $e');
      return 0;
    }
  }

  Future<void> reset() async {
    try {
      await _database.delete('sync_queue');
      debugPrint('[SyncQueueDb] Queue reset');
    } catch (e) {
      debugPrint('[SyncQueueDb] reset failed: $e');
    }
  }
}
