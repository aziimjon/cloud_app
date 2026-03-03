import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';
import 'models/folder_model.dart';
import 'models/file_model.dart';

class HomeRepository {
  final Dio _dio = DioClient.instance;

  // ── Получить ВСЕ страницы содержимого папки ───────────────────────────────
  // ✅ FIX: бэкенд отдаёт пагинацию (count:25, next:...?page=2)
  // Грузим все страницы, потом делаем client-side фильтр по parentId
  Future<Map<String, dynamic>> getContent({String? parentId}) async {
    try {
      final List<dynamic> allResults = [];

      // ✅ FIX: правильный endpoint для навигации по папкам
      final String endpoint = parentId == null
          ? '/content/folder/'
          : '/content/folder/$parentId/';
      var response = await _dio.get(endpoint);
      final dynamic responseData = response.data;

      // Определяем формат ответа: пагинированный или plain list
      if (responseData is List) {
        // Plain list — берём всё сразу
        allResults.addAll(responseData);
      } else {
        // Пагинированный: {count, next, results}
        allResults.addAll(responseData['results'] ?? []);

        // ✅ Грузим все оставшиеся страницы пока есть next
        String? nextUrl = responseData['next']?.toString();
        while (nextUrl != null && nextUrl.isNotEmpty) {
          // ✅ ВАЖНО: next URL содержит полный путь вида
          // http://192.168.1.100/api/v1/content/folder/?page=2
          // но baseUrl у нас /server/api/v1/ — извлекаем только ?page=N
          final uri = Uri.parse(nextUrl);
          final page = uri.queryParameters['page'];
          if (page == null) break;

          final pageResponse = await _dio.get(
            endpoint,
            queryParameters: {'page': page},
          );
          final pageData = pageResponse.data;

          if (pageData is List) {
            allResults.addAll(pageData);
            break;
          } else {
            allResults.addAll(pageData['results'] ?? []);
            nextUrl = pageData['next']?.toString();
          }
        }
      }

      final folders = allResults
          .where((e) => e['type'] == 'folder')
          .map((e) => FolderModel.fromJson(e))
          .toList();

      final files = allResults
          .where((e) => e['type'] == 'file')
          .map((e) => FileModel.fromJson(e))
          .toList();

      return {
        'folders': folders,
        'files': files,
        'count': allResults.length,
      };
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить файлы',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Создать папку ──────────────────────────────────────────────────────────
  Future<FolderModel> createFolder({
    required String name,
    String? parentId,
  }) async {
    try {
      final response = await _dio.post(
        '/content/folder/',
        data: {
          'name': name,
          if (parentId != null) 'parent': parentId,
        },
      );
      final data = response.data['result'] ?? response.data;
      return FolderModel.fromJson(data);
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось создать папку',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Переименовать файл или папку ──────────────────────────────────────────
  Future<void> renameItem({
    required String type,
    required String id,
    required String name,
  }) async {
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

  // ── Удалить файл или папку ────────────────────────────────────────────────
  Future<void> deleteItem({
    required String type,
    required String id,
  }) async {
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

  // ── Избранное: получить список ────────────────────────────────────────────
  Future<List<dynamic>> getFavouriteFiles() async {
    try {
      final response = await _dio.get('/content/favourite-file/');
      return response.data['results'] ?? response.data ?? [];
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить избранное',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Избранное: добавить ───────────────────────────────────────────────────
  Future<int> addToFavourites(String fileId) async {
    try {
      final response = await _dio.post(
        '/content/favourite-file/',
        data: {'file': fileId},
      );
      return response.data['id'] as int;
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось добавить в избранное',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Избранное: убрать ─────────────────────────────────────────────────────
  Future<void> removeFromFavourites(String fileId) async {
    try {
      await _dio.delete('/content/favourite-file/$fileId/');
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось убрать из избранного',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Недавние файлы ────────────────────────────────────────────────────────
  Future<List<dynamic>> getRecentFiles() async {
    try {
      final response = await _dio.get('/content/recent-files/');
      if (response.data is List) {
        return response.data as List;
      }
      return response.data['results'] ?? [];
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить недавние файлы',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Shared: получить список пользователей ─────────────────────────────────
  // ✅ FIX: id может прийти как String или int — обрабатываем оба варианта
  Future<List<dynamic>> getSharedWithMe() async {
    try {
      final response = await _dio.get('/content/shared-with-me/');
      return response.data['results'] ?? response.data ?? [];
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Не удалось загрузить Shared',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Shared: файлы конкретного пользователя ───────────────────────────────
  // ✅ FIX: userId теперь String (не int) — бэкенд может вернуть любой тип
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

  // ── Shared: папка конкретного пользователя ───────────────────────────────
  // ✅ FIX: userId теперь String
  Future<Map<String, dynamic>> getSharedFolder(
      String userId, String folderId) async {
    try {
      final response = await _dio
          .get('/content/shared-with-me/$userId/folder/$folderId/');
      return response.data;
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Ошибка',
        statusCode: e.response?.statusCode,
      );
    }
  }
}