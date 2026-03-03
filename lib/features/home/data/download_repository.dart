import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';

class DownloadRepository {
  Future<void> downloadFile({
    required String fileId,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        throw const AppException(message: 'No auth token');
      }

      // Определяем папку для сохранения
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw const AppException(message: 'Cannot access storage directory');
      }

      final savePath = '${dir.path}/$fileName';

      // Создаём отдельный Dio без логгера (иначе будет логировать байты)
      final downloadDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.instance.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      await downloadDio.download(
        'content/files/$fileId/download/',
        savePath,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
      );
    } on DioException catch (e) {
      throw AppException(
        message:
            e.response?.data?['message']?.toString() ??
            e.message ??
            'Download failed',
        statusCode: e.response?.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(message: 'Download failed: ${e.toString()}');
    }
  }

  /// Форматирование байтов в человекочитаемый вид
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
