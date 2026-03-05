import 'dart:async';

import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tus_client/tus_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';

class _TusDiskStore extends TusStore {
  final Directory _dir;
  _TusDiskStore(this._dir);

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

class UploadRepository {
  // Задержка перед возобновлением после восстановления сети
  static int resumeDelaySeconds = 3;

  static bool isAllowed(String fileName) {
    final mime = lookupMimeType(fileName) ?? '';
    return mime.startsWith('image/') || mime.startsWith('video/');
  }

  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'heif',
    'bmp',
    'tiff',
    'tif',
    'svg',
    'ico',
    'cr2',
    'nef',
    'arw',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'flv',
    'webm',
    'm4v',
    '3gp',
    'mpeg',
    'mpg',
    'ts',
    'mts',
  ];

  Future<void> uploadFile({
    required XFile file,
    String? parentId,
    required String userId,
    void Function(double progress)? onProgress,
    void Function()? onComplete,
    void Function(String status)? onStatusChange,
  }) async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) throw AppException(message: 'No auth token');

    final fileName = file.name;
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    if (!isAllowed(fileName)) {
      throw AppException(message: 'Разрешены только фото и видео файлы');
    }

    final metadata = {
      'filename': fileName,
      'filetype': mimeType,
      'owner': userId,
      if (parentId != null) 'folder_id': parentId,
    };

    final tempDir = await getTemporaryDirectory();
    final tusDir = Directory(p.join(tempDir.path, 'tus_uploads'));
    if (!tusDir.existsSync()) tusDir.createSync(recursive: true);
    final store = _TusDiskStore(tusDir);

    final client = TusClient(
      Uri.parse(AppConfig.instance.tusUrl),
      file,
      store: store,
      headers: {'Authorization': 'Bearer $token'},
      metadata: metadata,
      maxChunkSize: 512 * 1024,
    );

    bool isCompleted = false;
    StreamSubscription? connectivitySub;

    // Слушаем сеть только для UI статуса
    connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (isCompleted) return;
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        onStatusChange?.call('paused');
      } else {
        onStatusChange?.call('resumed');
      }
    });

    onStatusChange?.call('uploading');

    // Retry loop: при ошибке сети — ждём и пробуем снова
    // TusStore сохраняет offset → продолжаем с того места
    while (!isCompleted) {
      try {
        await client.upload(
          onProgress: (double progress) {
            onProgress?.call((progress / 100.0).clamp(0.0, 1.0));
          },
          onComplete: () {
            isCompleted = true;
            connectivitySub?.cancel();
            onComplete?.call();
          },
        );
        // Если upload() вернулся без onComplete — значит пауза или ошибка
        // Просто выходим из while, onComplete уже вызван или нет
        break;
      } catch (e) {
        // Сеть пропала — ждём connectivity и повторяем
        onStatusChange?.call('paused');

        // Ждём пока сеть вернётся
        await _waitForNetwork();

        onStatusChange?.call('resumed');
        await Future.delayed(Duration(seconds: resumeDelaySeconds));
        onStatusChange?.call('uploading');
        // Продолжаем while — upload() сам возьмёт offset из store
      }
    }

    connectivitySub?.cancel();
  }

  // Ожидает восстановления сети
  Future<void> _waitForNetwork() async {
    final completer = Completer<void>();
    StreamSubscription? sub;
    sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork && !completer.isCompleted) {
        sub?.cancel();
        completer.complete();
      }
    });
    // Таймаут 5 минут на случай если событие не придёт
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        sub?.cancel();
      },
    );
  }
}
