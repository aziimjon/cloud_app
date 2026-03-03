import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';
import '../data/upload_repository.dart';

enum _FileStatus { waiting, uploading, done, error, cancelled }

class _FileItem {
  final XFile file;
  final String name;
  _FileStatus status;
  double progress; // 0.0–1.0
  String? error;
  bool cancelRequested;

  _FileItem({
    required this.file,
    required this.name,
    this.status = _FileStatus.waiting,
    this.progress = 0,
    this.error,
    this.cancelRequested = false,
  });
}

class UploadPage extends StatefulWidget {
  final String? parentId;
  final VoidCallback? onUploadComplete;

  const UploadPage({super.key, this.parentId, this.onUploadComplete});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _repo = UploadRepository();
  final List<_FileItem> _queue = [];
  bool _isUploading = false;
  bool _allDone = false;
  static const int _maxFiles = 50;

  Future<void> _pickFiles() async {
    if (_isUploading) return;

    // ✅ Только фото и видео через image_and_video тип
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: UploadRepository.allowedExtensions,
    );

    if (result == null || result.files.isEmpty) return;

    final rejected = <String>[];

    setState(() {
      _allDone = false;
      for (final f in result.files) {
        if (f.path == null) continue;
        if (_queue.length >= _maxFiles) break;

        // Дополнительная проверка mime
        if (!UploadRepository.isAllowed(f.name)) {
          rejected.add(f.name);
          continue;
        }

        final alreadyAdded = _queue.any((q) => q.name == f.name);
        if (!alreadyAdded) {
          _queue.add(_FileItem(file: XFile(f.path!), name: f.name));
        }
      }
    });

    // Показать предупреждение если были отклонённые файлы
    if (rejected.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Пропущено ${rejected.length} файл(ов): только фото и видео',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (_queue.isNotEmpty &&
        _queue.any((f) => f.status == _FileStatus.waiting) &&
        !_isUploading) {
      await _startUploadAll();
    }
  }

  Future<void> _startUploadAll() async {
    final userId = await SecureStorage.getUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пользователь не найден'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    for (final item in _queue) {
      if (item.status != _FileStatus.waiting) continue;
      if (item.cancelRequested) {
        setState(() => item.status = _FileStatus.cancelled);
        continue;
      }

      setState(() {
        item.status = _FileStatus.uploading;
        item.progress = 0;
      });

      try {
        await _repo.uploadFile(
          file: item.file,
          parentId: widget.parentId,
          userId: userId,
          onProgress: (progress) {
            if (!mounted) return;
            // ✅ Проверяем отмену во время загрузки
            if (item.cancelRequested) return;
            setState(() => item.progress = progress);
          },
          onComplete: () {
            if (!mounted) return;
            if (item.cancelRequested) {
              setState(() => item.status = _FileStatus.cancelled);
            } else {
              setState(() {
                item.status = _FileStatus.done;
                item.progress = 1.0;
              });
            }
          },
        );
      } on AppException catch (e) {
        if (mounted) {
          setState(() {
            item.status =
            item.cancelRequested ? _FileStatus.cancelled : _FileStatus.error;
            item.error = e.message;
          });
        }
      }
    }

    if (mounted) {
      final hasSuccess = _queue.any((f) => f.status == _FileStatus.done);
      final allSettled = _queue.every((f) =>
      f.status == _FileStatus.done ||
          f.status == _FileStatus.error ||
          f.status == _FileStatus.cancelled);

      setState(() {
        _isUploading = false;
        _allDone = allSettled;
      });

      if (hasSuccess) {
        widget.onUploadComplete?.call();
      }
    }
  }

  // ✅ Задача 3: Отмена конкретного файла
  void _cancelFile(_FileItem item) {
    setState(() {
      item.cancelRequested = true;
      if (item.status == _FileStatus.waiting) {
        item.status = _FileStatus.cancelled;
      }
    });
  }

  void _removeFile(_FileItem item) {
    if (item.status == _FileStatus.uploading) return;
    setState(() => _queue.remove(item));
  }

  void _clearDone() {
    setState(() {
      _queue.removeWhere((f) =>
      f.status == _FileStatus.done ||
          f.status == _FileStatus.cancelled ||
          f.status == _FileStatus.error);
      _allDone = false;
    });
  }

  int get _waitingCount =>
      _queue.where((f) => f.status == _FileStatus.waiting).length;
  int get _doneCount =>
      _queue.where((f) => f.status == _FileStatus.done).length;
  int get _uploadingCount =>
      _queue.where((f) => f.status == _FileStatus.uploading).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Загрузка',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              background: Container(color: Colors.white),
            ),
            actions: [
              if (_queue.isNotEmpty && !_isUploading)
                TextButton(
                  onPressed: _clearDone,
                  child: const Text('Очистить',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Зона выбора ──────────────────────────────────────
                  GestureDetector(
                    onTap: _isUploading ? null : _pickFiles,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isUploading
                              ? Colors.blue
                              : Colors.blue.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _allDone
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_rounded,
                              color: _allDone ? Colors.green : Colors.blue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _allDone
                                ? 'Всё загружено!'
                                : _isUploading
                                ? 'Идёт загрузка...'
                                : 'Нажмите чтобы выбрать',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color:
                              _allDone ? Colors.green : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Только фото и видео · до $_maxFiles файлов',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Счётчик ──────────────────────────────────────────
                  if (_queue.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          '${_queue.length} / $_maxFiles',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_uploadingCount > 0)
                          _StatusBadge(
                              '$_uploadingCount загружается',
                              Colors.blue),
                        if (_doneCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _StatusBadge(
                                '$_doneCount готово', Colors.green),
                          ),
                        const Spacer(),
                        if (!_isUploading && _queue.length < _maxFiles)
                          TextButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text('Добавить',
                                style: TextStyle(fontSize: 13)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Список файлов ─────────────────────────────────────
                  ..._queue.map((item) => _FileItemTile(
                    item: item,
                    onCancel: item.status == _FileStatus.uploading ||
                        item.status == _FileStatus.waiting
                        ? () => _cancelFile(item)
                        : null,
                    onRemove: item.status != _FileStatus.uploading
                        ? () => _removeFile(item)
                        : null,
                  )),

                  const SizedBox(height: 16),

                  // ── Главная кнопка ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: _isUploading
                        ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                      label: const Text('Загрузка...',
                          style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                        : ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_photo_alternate_rounded,
                          color: Colors.white),
                      label: Text(
                        _queue.isEmpty
                            ? 'Выбрать фото / видео'
                            : _allDone
                            ? 'Загрузить ещё'
                            : 'Добавить ещё',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Один файл в очереди ───────────────────────────────────────────────────────
class _FileItemTile extends StatelessWidget {
  final _FileItem item;
  final VoidCallback? onCancel;  // во время загрузки — красный X
  final VoidCallback? onRemove;  // после — убрать из списка

  const _FileItemTile({
    required this.item,
    this.onCancel,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Иконка
              _buildIcon(),
              const SizedBox(width: 10),
              // Имя файла
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // ✅ Задача 3: Красный X при загрузке / серый X после
              if (onCancel != null)
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                  ),
                )
              else if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.grey),
                  ),
                ),
            ],
          ),

          // ── Прогресс бар ───────────────────────────────────────────
          if (item.status == _FileStatus.uploading) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress, // уже 0.0–1.0
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(item.progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],

          // ── Статус текст ────────────────────────────────────────────
          if (item.status == _FileStatus.done) ...[
            const SizedBox(height: 4),
            const Text('Загружено',
                style: TextStyle(fontSize: 11, color: Colors.green)),
          ],
          if (item.status == _FileStatus.cancelled) ...[
            const SizedBox(height: 4),
            Text('Отменено',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
          if (item.status == _FileStatus.error && item.error != null) ...[
            const SizedBox(height: 4),
            Text(item.error!,
                style: const TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (item.status) {
      case _FileStatus.waiting:
        return _iconBox(Icons.schedule_rounded, Colors.grey);
      case _FileStatus.uploading:
        return _iconBox(Icons.cloud_upload_rounded, Colors.blue);
      case _FileStatus.done:
        return _iconBox(Icons.check_circle_rounded, Colors.green);
      case _FileStatus.error:
        return _iconBox(Icons.error_outline_rounded, Colors.red);
      case _FileStatus.cancelled:
        return _iconBox(Icons.cancel_outlined, Colors.grey);
    }
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}