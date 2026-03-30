import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import 'models/folder_model.dart';
import 'models/file_model.dart';
import '../../../core/storage/secure_storage.dart';

class HomeRepository {
  final Dio _dio = DioClient.instance;

  /// Cached root folders for sync-folder guard checks (last resort).
  List<FolderModel> _cachedRootFolders = [];

  String _extractError(dynamic data) {
    if (data == null) return 'Unknown error';
    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('message')) return data['message'].toString();
      if (data.containsKey('non_field_errors')) {
        final errs = data['non_field_errors'];
        return errs is List ? errs.join(', ') : errs.toString();
      }
      return data.values.join(', ');
    } else if (data is List) {
      return data.join(', ');
    }
    return data.toString();
  }

  Future<Map<String, dynamic>> getContent({
    String? parentId,
    int page = 1,
  }) async {
    try {
      final String endpoint = parentId == null
          ? '/content/folder/'
          : '/content/folder/$parentId/';

      final response = await _dio.get(
        endpoint,
        queryParameters: {'page': page},
      );

      final dynamic responseData = response.data;
      final List<dynamic> results = responseData is List
          ? responseData
          : (responseData['results'] ?? []);

      final bool hasNext = responseData is Map &&
          responseData['next'] != null &&
          responseData['next'].toString().isNotEmpty;

      final folders = results
          .where((e) => e['type'] == 'folder')
          .map((e) => FolderModel.fromJson(e))
          .toList();

      final files = results
          .where((e) => e['type'] == 'file')
          .map((e) => FileModel.fromJson(e))
          .toList();

      final int totalCount = responseData is Map
          ? (responseData['count'] as int? ?? results.length)
          : results.length;

      // Cache root folders for sync-folder guards
      if (parentId == null) {
        _cachedRootFolders = folders;
      }

      return {
        'folders': folders,
        'files': files,
        'hasNext': hasNext,
        'count': results.length,
        'totalCount': totalCount,
      };
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить файлы',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<FolderModel> createFolder({
    required String name,
    String? parentId,
  }) async {
    try {
      // nginx redirects POST /folder/ → 404, so use direct Dio with no redirect
      final directDio = Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
      ));

      final t = await SecureStorage.getAccessToken();
      if (t != null) {
        directDio.options.headers['Authorization'] = 'Bearer $t';
      }

      final response = await directDio.post(
        '/content/folder/',
        data: {'name': name, if (parentId != null) 'parent': parentId},
      );

      if (response.statusCode == 404) {
        throw const AppException(message: 'Не удалось создать папку: Сервер вернул 404');
      }

      // API returns folder object directly (201 Created)
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return FolderModel.fromJson(data);
      }
      throw AppException(message: 'Неверный формат ответа (код: ${response.statusCode})');
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось создать папку',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Idempotent sync folder resolution — the ONLY place sync folder
  /// may be created. Checks server for existing is_sync folder first.
  Future<FolderModel> resolveSyncFolder() async {
    final result = await getContent(parentId: null);
    final folders = result['folders'] as List<FolderModel>;
    for (int i = 0; i < folders.length; i++) {
      final folder = folders[i];
      if (folder.isSync || folder.name == 'Sync') {
        debugPrint('[HomeRepo] Sync folder found: ${folder.id}');
        if (!folder.isSync) {
          // Обновляем "локальную БД" (кэш), устанавливая isSync = true
          final updatedFolder = folder.copyWith(isSync: true);
          final cacheIndex = _cachedRootFolders.indexWhere((f) => f.id == folder.id);
          if (cacheIndex != -1) {
            _cachedRootFolders[cacheIndex] = updatedFolder;
          }
          return updatedFolder;
        }
        return folder;
      }
    }
    // Not found on server — create it (server sets is_sync: true)
    debugPrint('[HomeRepo] No sync folder found, creating...');
    try {
      final response = await _dio.post(
        '/content/folder/',
        data: {'name': 'Sync', 'parent': null},
      );
      return FolderModel.fromJson(response.data);
    } catch (e) {
      debugPrint('[HomeRepo] Create sync folder failed: $e');
      rethrow;
    }
  }

  Future<void> renameItem({
    required String type,
    required String id,
    required String name,
  }) async {
    // Guard: sync folder cannot be renamed (last-resort check)
    if (type == 'folder') {
      if (_cachedRootFolders.any((f) => f.id == id && f.isSync)) {
        throw const AppException(message: 'Cannot modify sync folder');
      }
    }
    try {
      await _dio.patch(
        '/content/folder-file/rename/',
        data: {'type': type, 'id': id, 'name': name},
      );
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось переименовать',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> deleteItem({required String type, required String id, bool isSystem = false}) async {
    // Guard: system folders cannot be deleted
    if (type == 'folder' && isSystem) {
      throw const AppException(message: 'Cannot delete system folder');
    }
    // Guard: sync folder cannot be deleted (last-resort check)
    if (type == 'folder') {
      if (_cachedRootFolders.any((f) => f.id == id && f.isSync)) {
        throw const AppException(message: 'Cannot modify sync folder');
      }
    }
    try {
      await _dio.delete(
        '/content/folder-file/delete/',
        data: {
          'files': type == 'file' ? [id] : [],
          'folders': type == 'folder' ? [id] : [],
        },
      );
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось удалить',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> deleteItems({
    required List<String> files,
    required List<String> folders,
  }) async {
    // Guard: filter out sync folder from bulk deletion
    if (folders.isNotEmpty) {
      final syncIds = _cachedRootFolders
          .where((f) => f.isSync)
          .map((f) => f.id)
          .toSet();
      if (syncIds.isNotEmpty) {
        final before = folders.length;
        folders = folders.where((id) => !syncIds.contains(id)).toList();
        if (folders.length < before) {
          debugPrint('[HomeRepository] Blocked sync folder from bulk delete');
        }
      }
    }
    try {
      await _dio.delete(
        '/content/folder-file/delete/',
        data: {'files': files, 'folders': folders},
      );
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Не удалось удалить выбранные элементы',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> moveItems({
    required String? targetFolderId,
    required List<String> files,
    required List<String> folders,
  }) async {
    try {
      await _dio.patch(
        '/content/folder-file/move/',
        data: {
          'target_folder': targetFolderId,
          'files': files,
          'folders': folders,
        },
      );
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Не удалось переместить файлы',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<dynamic>> getFavouriteFiles() async {
    try {
      String? nextUrl = '/content/favourite-file/';
      List<dynamic> allResults = [];
      while (nextUrl != null) {
        final response = await _dio.get(nextUrl);
        if (response.data is Map<String, dynamic> &&
            response.data.containsKey('results')) {
          allResults.addAll(response.data['results']);
          nextUrl = response.data['next'];
        } else {
          // Fallback if not paginated
          allResults.addAll(response.data is List ? response.data : []);
          nextUrl = null;
        }
      }
      return allResults;
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Не удалось загрузить избранное',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<int> addToFavourites(String fileId) async {
    try {
      final response = await _dio.post(
        '/content/favourite-file/',
        data: {'file': fileId},
      );
      return response.data['id'] as int;
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Не удалось добавить в избранное',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> removeFromFavourites(String fileId) async {
    try {
      await _dio.delete('/content/favourite-file/$fileId/');
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Не удалось убрать из избранного',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPinnedFolders() async {
    try {
      final response = await _dio.get('/content/pinned-folders/');
      List<dynamic> raw = [];
      if (response.data is List) {
        raw = response.data as List;
      } else if (response.data is Map && response.data['results'] != null) {
        raw = response.data['results'];
      }
      return raw.map((item) {
        final folder = FolderModel.fromJson(item['folder'] as Map<String, dynamic>);
        return <String, dynamic>{
          'pinId': folder.id, // String UUID
          'folder': folder,
        };
      }).toList();
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить закрепленные папки',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> pinFolder(String folderUuid) async {
    try {
      await _dio.post(
        '/content/pinned-folders/',
        data: {'folder': folderUuid},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data?['message_key'] == 'you_can_pin_maximum_5_folders') {
        throw const AppException(message: 'Максимум 5 закреплённых папок');
      }
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось закрепить папку',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> unpinFolder(String folderUuid) async {
    try {
      await _dio.delete('/content/pinned-folders/$folderUuid/');
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось открепить папку',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Checks if a folder with the given [id] exists on the server.
  /// Returns true if the server returns a valid response, false on 404.
  Future<bool> folderExists(String id) async {
    try {
      final response = await _dio.get('/content/folder/$id/');
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>> getRecentFiles() async {
    try {
      final response = await _dio.get('/content/recent-files/');
      if (response.data is List) return response.data as List;
      return response.data['results'] ?? [];
    } on DioException catch (e) {
      throw AppException(
        message:
        e.response?.data?['message'] ??
            'Не удалось загрузить недавние файлы',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Preview endpoint — returns pre-signed MinIO URL for file streaming.
  /// Polls up to 10 times (every 2s) while server is generating the preview.
  Future<String?> getPreviewUrl(String fileId) async {
    if (fileId.isEmpty) return null;
    const maxAttempts = 10;
    const delay = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final token = await SecureStorage.getAccessToken();
        final response = await _dio.get(
          '/content/files/$fileId/preview/',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        dynamic data = response.data;
        if (data is Map && data['result'] is Map) {
          data = data['result'];
        }

        String? url;
        String status = '';
        if (data is Map) {
          url = data['url'] as String? ??
              data['preview_url'] as String? ??
              data['file_url'] as String? ??
              data['download_url'] as String?;
          status = data['preview_status'] as String? ?? '';
        } else if (data is String) {
          url = data;
        }

        // URL готов — возвращаем
        if (url != null && url.isNotEmpty) return _normalizeApiUrl(url);

        // Ещё генерируется — ждём и повторяем
        if (status == 'processing' || status == 'pending') {
          if (attempt < maxAttempts - 1) {
            await Future.delayed(delay);
            continue;
          }
        }

        // Превью не требуется — отдаём прямую ссылку на скачивание
        if (status == 'not_required' || status == 'completed') {
          return _normalizeApiUrl('/content/files/$fileId/download/');
        }

        return null;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return null;
        if (attempt < maxAttempts - 1) {
          await Future.delayed(delay);
          continue;
        }
        return null;
      }
    }
    return null;
  }

  String _normalizeApiUrl(String raw) {
    if (raw.isEmpty) return raw;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;

    final base = Uri.parse(AppConfig.instance.baseUrl);
    final origin = base.replace(path: '/', query: '', fragment: '');

    if (raw.startsWith('/media/') || raw.startsWith('/static/')) {
      return origin.resolve(raw).toString();
    }
    if (raw.startsWith('/api/')) {
      return origin.resolve(raw).toString();
    }
    if (raw.startsWith('/content/')) {
      return base.resolve(raw.substring(1)).toString();
    }
    if (raw.startsWith('/')) {
      return origin.resolve(raw).toString();
    }
    return base.resolve(raw).toString();
  }

  // ✅ FIX: id может быть String или int — всегда toString()
  Future<List<dynamic>> getSharedWithMe() async {
    try {
      final response = await _dio.get('/content/shared-with-me/');
      final raw = response.data is Map
          ? (response.data['results'] ?? [])
          : (response.data ?? []);
      if (raw is! List) return [];
      // Нормализуем id в String чтобы не было type cast errors
      return raw.map((item) {
        if (item is Map) {
          final normalized = Map<String, dynamic>.from(item);
          if (normalized['id'] != null) {
            normalized['id'] = normalized['id'].toString();
          }
          return normalized;
        }
        return item;
      }).toList();
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить Shared',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getSharedFromUser(String userId) async {
    try {
      final response = await _dio.get('/content/shared-with-me/$userId/');
      return response.data;
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Ошибка',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> getSharedFolder(
      String userId,
      String folderId,
      ) async {
    try {
      final response = await _dio.get(
        '/content/shared-with-me/$userId/folder/$folderId/',
      );
      return response.data;
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Ошибка',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
