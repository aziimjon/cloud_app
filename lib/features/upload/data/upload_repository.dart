import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:mime/mime.dart';
import 'package:tus_client/tus_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';

class UploadRepository {
  // ✅ Только фото и видео — все остальные форматы запрещены
  static bool isAllowed(String fileName) {
    final mime = lookupMimeType(fileName) ?? '';
    return mime.startsWith('image/') || mime.startsWith('video/');
  }

  static const List<String> allowedExtensions = [
    // Фото
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp', 'tiff',
    'tif', 'svg', 'ico', 'raw', 'cr2', 'nef', 'arw',
    // Видео
    'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', 'm4v', '3gp',
    'mpeg', 'mpg', 'ts', 'mts',
  ];

  Future<void> uploadFile({
    required XFile file,
    String? parentId,
    required String userId,
    void Function(double progress)? onProgress,
    void Function()? onComplete,
  }) async {
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) throw AppException(message: 'No auth token');

      final fileName = file.name;
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

      // ✅ Проверка типа файла
      if (!isAllowed(fileName)) {
        throw AppException(
          message: 'Разрешены только фото и видео файлы',
        );
      }

      String b64(String s) => base64.encode(utf8.encode(s));

      final metadata = {
        'filename': b64(fileName),
        'filetype': b64(mimeType),
        'owner': b64(userId),
        if (parentId != null) 'parent_id': b64(parentId),
      };

      final client = TusClient(
        Uri.parse(AppConfig.instance.tusUrl),
        file,
        metadata: metadata,
        headers: {'Authorization': 'Bearer $token'},
      );

      await client.upload(
        onProgress: (double progress) {
          // ✅ tus_client даёт 0–100, делаем 0.0–1.0
          onProgress?.call((progress / 100.0).clamp(0.0, 1.0));
        },
        onComplete: () {
          onComplete?.call();
        },
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(message: 'Upload failed: ${e.toString()}');
    }
  }
}