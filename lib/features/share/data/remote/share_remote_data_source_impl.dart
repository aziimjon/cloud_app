import 'package:dio/dio.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/share_models.dart';
import 'share_remote_data_source.dart';

/// Dio-based implementation of [ShareRemoteDataSource].
class ShareRemoteDataSourceImpl implements ShareRemoteDataSource {
  final Dio _dio;

  ShareRemoteDataSourceImpl(this._dio);

  Future<Options> _authOptions() async {
    final token = await SecureStorage.getAccessToken();
    return Options(
      contentType: 'application/json',
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  @override
  Future<List<FileShareModel>> getSharedByMe() async {
    try {
      final options = await _authOptions();
      final response =
      await _dio.get('/content/shared-by-me/', options: options);
      final raw = response.data;
      final List<dynamic> list =
      raw is List ? raw : (raw is Map ? (raw['results'] ?? []) : []);
      return list
          .map((e) => FileShareModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось загрузить shared by me');
    }
  }

  @override
  Future<FileShareModel> shareFiles(FileShareCreateModel body) async {
    try {
      final options = await _authOptions();
      final response = await _dio.post(
        '/content/shared-by-me/',
        data: body.toJson(),
        options: options,
      );
      return FileShareModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось поделиться файлами');
    }
  }

  @override
  Future<FileShareModel> revokeShare({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
    List<String> phoneNumbers = const [],
  }) async {
    try {
      final options = await _authOptions();
      final response = await _dio.delete(
        '/content/shared-by-me/',
        data: {
          'file_ids': fileIds,
          'folder_ids': folderIds,
          if (phoneNumbers.isNotEmpty) 'phone_numbers': phoneNumbers,
        },
        options: options,
      );
      return FileShareModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось отозвать доступ');
    }
  }

  @override
  Future<List<SharedByMeUserModel>> getSharedByMeUsers() async {
    try {
      final options = await _authOptions();
      final response =
      await _dio.get('/content/shared-by-me/users/', options: options);
      final raw = response.data;
      final List<dynamic> list =
      raw is List ? raw : (raw is Map ? (raw['results'] ?? []) : []);
      return list
          .map((e) => SharedByMeUserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ??
          'Не удалось загрузить пользователей');
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedByMeUser(int userId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '/content/shared-by-me/$userId/',
        options: options,
      );
      return ControllerDefaultResponseModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось загрузить файлы');
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedByMeUserFolder(
      int userId, String folderId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '/content/shared-by-me/$userId/folder/$folderId/',
        options: options,
      );
      return ControllerDefaultResponseModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось загрузить папку');
    }
  }

  @override
  Future<List<SharedWithMeUserModel>> getSharedWithMe() async {
    try {
      final options = await _authOptions();
      final response =
      await _dio.get('/content/shared-with-me/', options: options);
      final raw = response.data;
      final List<dynamic> list =
      raw is List ? raw : (raw is Map ? (raw['results'] ?? []) : []);
      return list
          .map((e) => SharedWithMeUserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ??
          'Не удалось загрузить shared with me');
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedWithMeUser(
      int userId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '/content/shared-with-me/$userId/',
        options: options,
      );
      return ControllerDefaultResponseModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось загрузить файлы');
    }
  }

  @override
  Future<ControllerDefaultResponseModel> getSharedWithMeUserFolder(
      int userId, String folderId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '/content/shared-with-me/$userId/folder/$folderId/',
        options: options,
      );
      return ControllerDefaultResponseModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось загрузить папку');
    }
  }

  // ================= NEW SHARE REQUEST METHODS =================

  @override
  Future<ShareRequestListModel> createShareRequest(
      ShareRequestCreateModel body) async {
    try {
      final options = await _authOptions();
      final response = await _dio.post(
        '/content/share-request/',
        data: body.toJson(),
        options: options,
      );
      return ShareRequestListModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось создать share request');
    }
  }

  @override
  Future<List<ShareRequestListModel>> getShareRequests() async {
    try {
      final options = await _authOptions();
      final response =
      await _dio.get('/content/share-request/', options: options);
      final raw = response.data;
      final List<dynamic> list =
      raw is List ? raw : (raw is Map ? (raw['results'] ?? []) : []);
      return list
          .map((e) =>
          ShareRequestListModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ??
          'Не удалось загрузить share requests');
    }
  }

  @override
  Future<ShareRequestDetailModel> getShareRequestDetail(int id) async {
    try {
      final options = await _authOptions();
      final response = await _dio.get(
        '/content/share-request/$id/',
        options: options,
      );
      return ShareRequestDetailModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось загрузить детали');
    }
  }

  @override
  Future<ShareRequestPermission> updatePermissionStatus({
    required int permissionId,
    required String status,
  }) async {
    try {
      final options = await _authOptions();
      final response = await _dio.patch(
        '/content/share-request-permission/$permissionId/',
        data: {'status': status},
        options: options,
      );
      return ShareRequestPermission.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          e.response?.data?['message'] ?? 'Не удалось обновить статус');
    }
  }
}