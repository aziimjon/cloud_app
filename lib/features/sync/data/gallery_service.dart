import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GalleryFile {
  final String id;
  final String name;
  final int size;
  final String mimeType;
  final String uploadStatus;
  final String? capturedAt;
  final String? thumbnailPath;

  const GalleryFile({
    required this.id,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.uploadStatus,
    this.capturedAt,
    this.thumbnailPath,
  });

  factory GalleryFile.fromJson(Map<String, dynamic> json) {
    return GalleryFile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? '',
      uploadStatus: json['upload_status'] as String? ?? '',
      capturedAt: json['captured_at'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
    );
  }
}

class GalleryService {
  final Dio _dio;

  GalleryService({required String baseUrl, required String token})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// GET /content/gallery/
  /// Returns Set<"name|size"> for deduplication during cold start.
  Future<Set<String>> getUploadedFileKeys() async {
    try {
      final response = await _dio.get('/content/gallery/');
      final data = response.data;
      final List<dynamic> items = data is List ? data : (data['result'] ?? []);
      final keys = <String>{};
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String? ?? '';
          final size = (item['size'] as num?)?.toInt() ?? 0;
          if (name.isNotEmpty) {
            keys.add('$name|$size');
          }
        }
      }
      debugPrint('[GalleryService] Loaded ${keys.length} file keys');
      return keys;
    } catch (e) {
      debugPrint('[GalleryService] getUploadedFileKeys failed: $e');
      rethrow;
    }
  }

  /// GET /content/gallery/
  /// Returns full list of gallery files.
  Future<List<GalleryFile>> getGallery() async {
    try {
      final response = await _dio.get('/content/gallery/');
      final data = response.data;
      final List<dynamic> items = data is List ? data : (data['result'] ?? []);
      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => GalleryFile.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[GalleryService] getGallery failed: $e');
      rethrow;
    }
  }

  /// GET /content/statistics/
  /// Returns raw stats map.
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _dio.get('/content/statistics/');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['result'] as Map<String, dynamic>? ?? data;
      }
      return {};
    } catch (e) {
      debugPrint('[GalleryService] getStatistics failed: $e');
      rethrow;
    }
  }

  /// GET /content/recent-files/?size=N
  Future<List<GalleryFile>> getRecentFiles({int size = 20}) async {
    try {
      final response = await _dio.get(
        '/content/recent-files/',
        queryParameters: {'size': size},
      );
      final data = response.data;
      final List<dynamic> items = data is List ? data : (data['result'] ?? []);
      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => GalleryFile.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[GalleryService] getRecentFiles failed: $e');
      rethrow;
    }
  }

  /// GET /content/files/{uuid}/download/
  /// uuid must be valid UUID string — integers return 404.
  Future<Map<String, dynamic>> getDownloadInfo(String uuid) async {
    if (uuid.isEmpty) {
      throw ArgumentError('UUID cannot be empty');
    }
    try {
      final response = await _dio.get('/content/files/$uuid/download/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GalleryService] getDownloadInfo($uuid) failed: $e');
      rethrow;
    }
  }
}
