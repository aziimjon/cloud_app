import 'package:cross_file/cross_file.dart';
import 'package:tus_client/tus_client.dart';
import 'package:cloud_app/core/config/app_config.dart';

class TusUploadService {
  Future<void> uploadFile({
    required XFile file,
    required void Function(int sent, int total) onProgress,
  }) async {
    final totalBytes = await file.length();

    final client = TusClient(
      Uri.parse(AppConfig.instance.tusUrl),
      file,
    );

    await client.upload(
      onProgress: (double progress) {
        final sentBytes = (totalBytes * progress).toInt();
        onProgress(sentBytes, totalBytes);
      },
    );
  }

  Future<void> uploadMultiple(
      List<XFile> files,
      void Function(int sent, int total) onProgress,
      ) async {
    int totalBytes = 0;

    for (final file in files) {
      totalBytes += await file.length();
    }

    int uploadedBytes = 0;

    for (final file in files) {
      await uploadFile(
        file: file,
        onProgress: (sent, total) {
          onProgress(uploadedBytes + sent, totalBytes);
        },
      );

      uploadedBytes += await file.length();
    }
  }
}