import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../data/sync_queue_db.dart';
import '../data/sync_task.dart';

class MediaScanner {
  final SyncQueueDb db;
  final Set<String> uploadedKeys;

  MediaScanner({required this.db, required this.uploadedKeys});

  /// Scans device gallery, deduplicates, and enqueues new items.
  /// Returns count of newly added pending items.
  Future<int> scanAndEnqueue() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        debugPrint('[MediaScanner] Permission denied');
        return 0;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, // images + videos
        hasAll: true,
      );

      if (albums.isEmpty) {
        debugPrint('[MediaScanner] No albums found');
        return 0;
      }

      int enqueued = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final album in albums) {
        final assetCount = await album.assetCountAsync;
        if (assetCount == 0) continue;

        // Load assets in batches of 100 to avoid memory issues
        const batchSize = 100;
        for (int offset = 0; offset < assetCount; offset += batchSize) {
          final remaining = assetCount - offset;
          final count = remaining < batchSize ? remaining : batchSize;
          final assets = await album.getAssetListRange(
            start: offset,
            end: offset + count,
          );

          for (final asset in assets) {
            try {
              // Skip if already in local DB
              if (await db.exists(asset.id)) continue;

              // Get file reference
              final file = await asset.originFile;
              if (file == null) continue;

              final name = asset.title ?? p.basename(file.path);
              final size = file.lengthSync();
              final key = '$name|$size';

              // Check if already uploaded to server (cold start dedup)
              if (uploadedKeys.contains(key)) {
                await db.insertOrIgnore(SyncTask(
                  localId: asset.id,
                  filePath: file.path,
                  fileName: name,
                  fileSize: size,
                  mimeType: _mimeForAsset(asset),
                  status: SyncStatus.done,
                  createdAt: now,
                  updatedAt: now,
                ));
                continue;
              }

              // Compute hash for deduplication
              final hash = await _computeHash(asset, file, size);

              // Check if a file with the same hash was already uploaded
              if (hash != null && await db.isDoneByHash(hash)) {
                await db.insertOrIgnore(SyncTask(
                  localId: asset.id,
                  filePath: file.path,
                  fileName: name,
                  fileSize: size,
                  mimeType: _mimeForAsset(asset),
                  sha256: hash,
                  status: SyncStatus.done,
                  createdAt: now,
                  updatedAt: now,
                ));
                continue;
              }

              // Enqueue as pending
              await db.insertOrIgnore(SyncTask(
                localId: asset.id,
                filePath: file.path,
                fileName: name,
                fileSize: size,
                mimeType: _mimeForAsset(asset),
                sha256: hash,
                status: SyncStatus.pending,
                createdAt: now,
                updatedAt: now,
              ));
              enqueued++;
            } catch (e) {
              debugPrint('[MediaScanner] Error processing asset ${asset.id}: $e');
            }
          }
        }
      }

      debugPrint('[MediaScanner] Scan complete: $enqueued new items enqueued');
      return enqueued;
    } catch (e) {
      debugPrint('[MediaScanner] scanAndEnqueue failed: $e');
      return 0;
    }
  }

  /// Computes SHA-256 hash.
  /// - Images: full file bytes
  /// - Videos: first 1MB + file size string appended
  Future<String?> _computeHash(AssetEntity asset, File file, int size) async {
    try {
      Uint8List bytes;
      if (asset.type == AssetType.video) {
        // For videos: read first 1MB + append size string
        const maxBytes = 1024 * 1024; // 1MB
        final raf = await file.open(mode: FileMode.read);
        try {
          final readLength = size < maxBytes ? size : maxBytes;
          bytes = await raf.read(readLength);
        } finally {
          await raf.close();
        }
        final sizeBytes = utf8.encode(size.toString());
        final combined = Uint8List(bytes.length + sizeBytes.length);
        combined.setRange(0, bytes.length, bytes);
        combined.setRange(bytes.length, combined.length, sizeBytes);
        bytes = combined;
      } else {
        bytes = await file.readAsBytes();
      }

      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint('[MediaScanner] Hash computation failed: $e');
      return null;
    }
  }

  String _mimeForAsset(AssetEntity asset) {
    switch (asset.type) {
      case AssetType.image:
        return asset.mimeType ?? 'image/jpeg';
      case AssetType.video:
        return asset.mimeType ?? 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
