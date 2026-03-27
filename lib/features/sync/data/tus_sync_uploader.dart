import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tus_client/tus_client.dart';

import '../../../core/config/app_config.dart';
import 'sync_task.dart';

class TusUploadException implements Exception {
  final String message;
  TusUploadException(this.message);

  @override
  String toString() => 'TusUploadException: $message';
}

/// Disk-based TUS store for resumable uploads (matches upload_repository.dart pattern).
class _SyncTusDiskStore extends TusStore {
  final Directory _dir;
  _SyncTusDiskStore(this._dir);

  String _keyFile(String fingerprint) => p.join(
        _dir.path,
        '${fingerprint.replaceAll(RegExp(r'[^\w]'), '_')}.tusurl',
      );

  @override
  Future<Uri?> get(String fingerprint) async {
    try {
      final f = File(_keyFile(fingerprint));
      if (!await f.exists()) return null;
      final url = await f.readAsString();
      return Uri.tryParse(url);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> set(String fingerprint, Uri url) async {
    try {
      await File(_keyFile(fingerprint)).writeAsString(url.toString());
    } catch (_) {}
  }

  @override
  Future<void> remove(String fingerprint) async {
    try {
      final f = File(_keyFile(fingerprint));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class TusSyncUploader {
  final String authToken;

  TusSyncUploader({required this.authToken});

  /// Uploads a file via TUS protocol and returns the server UUID
  /// extracted from the upload URL.
  /// [folderId] — if provided, the file will be placed into this folder
  /// via TUS metadata (matches upload_repository.dart pattern).
  Future<String> upload(
    SyncTask task, {
    String? folderId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(task.filePath);
      if (!file.existsSync()) {
        throw TusUploadException('File not found: ${task.filePath}');
      }

      debugPrint('[Sync] Uploading file → ${task.fileName}');

      final xFile = XFile(task.filePath);
      final mimeType =
          lookupMimeType(task.fileName) ?? 'application/octet-stream';

      final metadata = {
        'filename': task.fileName,
        'filetype': mimeType,
        if (folderId != null) 'folder_id': folderId,
      };

      final tempDir = await getTemporaryDirectory();
      final tusDir = Directory(p.join(tempDir.path, 'tus_sync_uploads'));
      if (!tusDir.existsSync()) tusDir.createSync(recursive: true);
      final store = _SyncTusDiskStore(tusDir);

      final tusUrl = AppConfig.instance.tusUrl;
      final client = TusClient(
        Uri.parse(tusUrl),
        xFile,
        store: store,
        headers: {'Authorization': 'Bearer $authToken'},
        metadata: metadata,
        maxChunkSize: 512 * 1024,
      );

      String? uploadUrl;

      await client.upload(
        onProgress: (double progress) {
          onProgress?.call((progress / 100.0).clamp(0.0, 1.0));
        },
        onComplete: () {
          debugPrint('[TusSyncUploader] Upload complete for ${task.fileName}');
        },
      );

      // Extract the upload URL after completion
      uploadUrl = client.uploadUrl?.toString();

      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw TusUploadException(
            'Upload completed but no URL returned for ${task.fileName}');
      }

      // Extract UUID — last path segment of the upload URL
      final uri = Uri.parse(uploadUrl);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        throw TusUploadException(
            'Cannot extract UUID from upload URL: $uploadUrl');
      }
      final serverUuid = segments.last;

      if (serverUuid.isEmpty) {
        throw TusUploadException(
            'Extracted empty UUID from upload URL: $uploadUrl');
      }

      debugPrint('[Sync] Uploaded → ${task.fileName}, folder=$folderId, uuid=$serverUuid');
      return serverUuid;
    } on TusUploadException {
      rethrow;
    } catch (e) {
      throw TusUploadException('Upload failed for ${task.fileName}: $e');
    }
  }
}
