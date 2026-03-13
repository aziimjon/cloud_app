import 'dart:ui';
import 'package:flutter/material.dart';
import '../data/home_repository.dart';
import '../data/download_repository.dart';
import '../data/models/folder_model.dart';
import '../data/models/file_model.dart';
import '../../../core/errors/app_exception.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/storage/secure_storage.dart';
import 'package:cloud_app/features/home/presentation/move_destination_screen.dart';
import '../../upload/presentation/upload_page.dart';
import 'photo_viewer_page.dart';
import 'video_player_page.dart';
import '../../../core/providers/favourites_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../../../main.dart';

// ✅ Задача 5: только Все, Фото, Видео
enum _FilterType { all, images, videos }

class HomePage extends StatefulWidget {
  final void Function(String? folderId)? onFolderChanged;

  const HomePage({super.key, this.onFolderChanged});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _repo = HomeRepository();
  final _downloadRepo = DownloadRepository();
  final _profileRepo = ProfileRepository();
  Map<String, dynamic> _storageData = {};

  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  bool _isLoading = true;
  String? _error;
  bool _isGrid = true;
  String? _userName;
  String? _authToken;
  final Map<String, String> _previewUrls = {};

  final Map<String, double> _downloadProgress = {};
  final Map<String, int> _downloadReceivedBytes = {};

  final List<({String id, String name})> _breadcrumb = [];

  bool _showFavourites = false;
  _FilterType _activeFilter = _FilterType.all;

  bool get _isSelectionMode =>
      _selectedFiles.isNotEmpty || _selectedFolders.isNotEmpty;
  final Set<String> _selectedFiles = {};
  final Set<String> _selectedFolders = {};

  List<Map<String, dynamic>> _pinnedFolders = [];
  int _folderPage = 0;

  Widget _buildPaginationRow({
    required int page,
    required bool isLastPage,
    required ValueChanged<int> onPageChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: page == 0 ? null : () => onPageChanged(page - 1),
        ),
        Text('${page + 1}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isLastPage ? null : () => onPageChanged(page + 1),
        ),
      ],
    );
  }

  String? _getPinId(String folderId) {
    for (final pin in _pinnedFolders) {
      final folder = pin['folder'];
      if (folder is FolderModel && folder.id == folderId) return pin['pinId'] as String?;
    }
    return null;
  }

  Future<void> _pinFolder(FolderModel folder) async {
    if (_pinnedFolders.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Максимум 5 закреплённых папок')),
        );
      }
      return;
    }
    if (_getPinId(folder.id) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Папка уже закреплена')),
        );
      }
      return;
    }
    // Optimistic update
    final newPin = {'pinId': folder.id, 'folder': folder};
    setState(() => _pinnedFolders = [..._pinnedFolders, newPin]);
    try {
      await _repo.pinFolder(folder.id);
    } on AppException catch (e) {
      // Revert on error
      setState(() => _pinnedFolders = _pinnedFolders.where((p) => p['pinId'] != folder.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _unpinFolder(String pinId) async {
    // Save for revert
    final backup = List<Map<String, dynamic>>.from(_pinnedFolders);
    // Optimistic remove
    setState(() => _pinnedFolders = _pinnedFolders.where((p) => p['pinId'] != pinId).toList());
    try {
      await _repo.unpinFolder(pinId);
    } on AppException catch (e) {
      // Revert on error
      setState(() => _pinnedFolders = backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  void _toggleFolderSelection(String id) {
    setState(() {
      if (_selectedFolders.contains(id)) {
        _selectedFolders.remove(id);
      } else {
        _selectedFolders.add(id);
      }
    });
  }

  void _toggleFileSelection(String id) {
    setState(() {
      if (_selectedFiles.contains(id)) {
        _selectedFiles.remove(id);
      } else {
        _selectedFiles.add(id);
      }
    });
  }

  String? get _currentFolderId =>
      _breadcrumb.isEmpty ? null : _breadcrumb.last.id;

  List<FileModel> get _displayFiles {
    final source = _showFavourites
        ? FavouritesProvider.instance.favouriteFiles
        : _files;

    final syncedSource = source
        .map(
          (f) => f.copyWith(
            isFavourite: FavouritesProvider.instance.isFavourite(f.id),
          ),
        )
        .toList();

    if (_activeFilter == _FilterType.all) return syncedSource;
    return syncedSource.where((f) => _matchesFilter(f, _activeFilter)).toList();
  }

  List<FolderModel> get _displayFolders => _showFavourites ? [] : _folders;

  bool _matchesFilter(FileModel f, _FilterType filter) {
    final m = f.mimeType.toLowerCase();
    switch (filter) {
      case _FilterType.images:
        return m.startsWith('image/');
      case _FilterType.videos:
        return m.startsWith('video/');
      case _FilterType.all:
        return true;
    }
  }

  String _fmt(dynamic b) {
    if (b == null) return '0 КБ';
    final v = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
    if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(2)} ГБ';
    if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(1)} МБ';
    return '${(v / 1024).toStringAsFixed(0)} КБ';
  }

  Future<void> _loadStorageData() async {
    try {
      final data = await _profileRepo.getStorageUsed();
      if (mounted) setState(() => _storageData = data);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    FavouritesProvider.instance.loadFavourites();
    _loadUserName();
    _loadContent();
    _loadAuthToken();
    _loadStorageData();
  }

  Future<void> _loadAuthToken() async {
    final token = await SecureStorage.getAccessToken();
    if (mounted) setState(() => _authToken = token);
  }

  void _loadPreviewUrls(List<FileModel> files) {
    for (final f in files) {
      if (f.thumbnailPath != null &&
          f.thumbnailPath!.isNotEmpty &&
          !_previewUrls.containsKey(f.id)) {
        _previewUrls[f.id] = f.thumbnailPath!;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _openFileViewer(FileModel file) async {
    final mime = file.mimeType.toLowerCase();
    if (mime.startsWith('image/')) {
      final fullUrl = await _repo.getPreviewUrl(file.id);
      if (fullUrl == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть изображение')),
          );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PhotoViewerPage(imageUrl: fullUrl, fileName: file.name),
        ),
      );
    } else if (mime.startsWith('video/')) {
      final url = await _repo.getPreviewUrl(file.id);
      if (url == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть видео')),
          );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(videoUrl: url, fileName: file.name),
        ),
      );
    }
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.getContent(parentId: _currentFolderId);
      // Load pinned folders
      List<Map<String, dynamic>> pinned = [];
      try {
        pinned = await _repo.getPinnedFolders();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _folders = result['folders'] as List<FolderModel>;
        _files = result['files'] as List<FileModel>;
        _pinnedFolders = pinned;
        _isLoading = false;
      });
      _loadPreviewUrls(_files);
      _loadStorageData();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserName() async {
    final name = await SecureStorage.getFullName();
    if (!mounted) return;
    setState(() => _userName = name);
  }

  void reloadContent() => _loadContent();

  // ✅ ФИК #1: сохраняем folderId ДО push + reload после возврата
  void _openUploadPage() {
    final currentFolder = _currentFolderId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadPage(
          parentId: currentFolder,
          onUploadComplete: () async {
            // Ждём пока бэкенд обработает TUS webhook
            await Future.delayed(const Duration(seconds: 2));
            _loadContent();
          },
        ),
      ),
    ).then((_) {
      // Также обновляем при возврате с Upload страницы
      _loadContent();
    });
  }

  void _openFolder(FolderModel folder) {
    setState(() {
      _breadcrumb.add((id: folder.id, name: folder.name));
      _showFavourites = false;
      _activeFilter = _FilterType.all;
      _folderPage = 0;
    });
    widget.onFolderChanged?.call(folder.id);
    _loadContent();
  }

  void _navigateTo(int index) {
    if (index < 0) {
      if (_breadcrumb.isEmpty) return;
      setState(() {
        _breadcrumb.clear();
        _folderPage = 0;
      });
      widget.onFolderChanged?.call(null);
    } else {
      if (index == _breadcrumb.length - 1) return;
      setState(() {
        _breadcrumb.removeRange(index + 1, _breadcrumb.length);
        _folderPage = 0;
      });
      widget.onFolderChanged?.call(_breadcrumb[index].id);
    }
    _loadContent();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Фильтр',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterChip(
                    label: 'Все',
                    icon: Icons.apps_rounded,
                    isActive: _activeFilter == _FilterType.all,
                    onTap: () {
                      setState(() => _activeFilter = _FilterType.all);
                      Navigator.pop(ctx);
                    },
                  ),
                  _FilterChip(
                    label: 'Фото',
                    icon: Icons.image_rounded,
                    isActive: _activeFilter == _FilterType.images,
                    onTap: () {
                      setState(() => _activeFilter = _FilterType.images);
                      Navigator.pop(ctx);
                    },
                  ),
                  _FilterChip(
                    label: 'Видео',
                    icon: Icons.videocam_rounded,
                    isActive: _activeFilter == _FilterType.videos,
                    onTap: () {
                      setState(() => _activeFilter = _FilterType.videos);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
      ),
    );
      },
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.create_new_folder,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Новая папка',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Название папки',
                  hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.blue,
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.folder, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          final newFolder = await _repo.createFolder(
                            name: name,
                            parentId: _currentFolderId,
                          );
                          _openFolder(newFolder);
                        } on AppException catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Создать',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildBottomSheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minVerticalPadding: 0,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color == Colors.red ? Colors.red : onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showFolderMenu(FolderModel folder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildBottomSheetItem(
                icon: Icons.folder_open,
                color: Colors.blue,
                title: 'Открыть',
                onTap: () {
                  Navigator.pop(ctx);
                  _openFolder(folder);
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.drive_file_rename_outline,
                color: Colors.orange,
                title: 'Переименовать',
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(
                    currentName: folder.name,
                    onRename: (newName) async {
                      try {
                        await _repo.renameItem(
                          type: 'folder',
                          id: folder.id,
                          name: newName,
                        );
                        if (!mounted) return;
                        _loadContent();
                      } on AppException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.arrow_forward_rounded,
                color: Colors.blue,
                title: 'Переместить',
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MoveDestinationScreen(
                        selectedFiles: const [],
                        selectedFolders: [folder.id],
                        currentFolderId: _currentFolderId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadContent();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Успешно перемещено'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.delete_outline,
                color: Colors.red,
                title: 'Удалить',
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(
                    itemName: folder.name,
                    onConfirm: () async {
                      try {
                        await _repo.deleteItem(type: 'folder', id: folder.id);
                        if (!mounted) return;
                        _loadContent();
                      } on AppException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              Builder(
                builder: (_) {
                  final pinId = _getPinId(folder.id);
                  final isPinned = pinId != null;
                  return _buildBottomSheetItem(
                    icon: Icons.push_pin_outlined,
                    color: isPinned ? Colors.orange : Colors.blueGrey,
                    title: isPinned ? '📌 Открепить' : '📌 Закрепить',
                    onTap: () {
                      Navigator.pop(ctx);
                      if (isPinned) {
                        _unpinFolder(pinId);
                      } else {
                        _pinFolder(folder);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  IconData _icon(String mime) {
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.videocam_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _color(String mime) {
    if (mime.startsWith('image/')) return const Color(0xFF34A853);
    if (mime.startsWith('video/')) return const Color(0xFFEA4335);
    return const Color(0xFF1A73E8);
  }

  void _showFileMenu(FileModel file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _color(file.mimeType).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _icon(file.mimeType),
                        color: _color(file.mimeType),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            file.formattedSize,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildBottomSheetItem(
                icon: file.isFavourite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: file.isFavourite ? Colors.amber : Colors.grey,
                title: file.isFavourite
                    ? 'Убрать из избранного'
                    : 'В избранное',
                onTap: () {
                  Navigator.pop(ctx);
                  FavouritesProvider.instance.toggleFavourite(file);
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.download_rounded,
                color: Colors.blue,
                title: 'Скачать',
                onTap: () {
                  Navigator.pop(ctx);
                  _startDownload(file);
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.drive_file_rename_outline,
                color: Colors.orange,
                title: 'Переименовать',
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(
                    currentName: file.name,
                    onRename: (newName) async {
                      try {
                        await _repo.renameItem(
                          type: 'file',
                          id: file.id,
                          name: newName,
                        );
                        if (!mounted) return;
                        _loadContent();
                      } on AppException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.arrow_forward_rounded,
                color: Colors.blue,
                title: 'Переместить',
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MoveDestinationScreen(
                        selectedFiles: [file.id],
                        selectedFolders: const [],
                        currentFolderId: _currentFolderId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadContent();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Успешно перемещено'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _buildBottomSheetItem(
                icon: Icons.delete_outline,
                color: Colors.red,
                title: 'Удалить',
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(
                    itemName: file.name,
                    onConfirm: () async {
                      try {
                        await _repo.deleteItem(type: 'file', id: file.id);
                        if (!mounted) return;
                        _loadContent();
                      } on AppException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showRenameDialog({
    required String currentName,
    required Future<void> Function(String) onRename,
  }) {
    final controller = TextEditingController(text: currentName);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surface,
        title: Text('Переименовать', style: TextStyle(color: cs.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Новое название',
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              onRename(newName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog({
    required String itemName,
    required Future<void> Function() onConfirm,
  }) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surface,
        title: Text('Удалить?', style: TextStyle(color: cs.onSurface)),
        content: Text(
          'Вы уверены, что хотите удалить «$itemName»?\nЭто действие необратимо.',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavouritesProvider.instance,
      builder: (context, _) {
        return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildBreadcrumb()),
                SliverToBoxAdapter(child: _buildStorageInfo()),
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  SliverFillRemaining(child: _buildError())
                else if (FavouritesProvider.instance.isLoading &&
                    _showFavourites)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_showFavourites &&
                    FavouritesProvider.instance.favouriteFiles.isEmpty)
                  SliverFillRemaining(child: _buildEmptyFavourites())
                else if (!_showFavourites &&
                    _displayFolders.isEmpty &&
                    _displayFiles.isEmpty)
                  SliverFillRemaining(child: _buildEmpty())
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 80,
                    ),
                    sliver: _buildContent(),
                  ),
              ],
            ),
            _buildBottomActionBar(),
          ],
        ),
        floatingActionButton: _buildFABs(),
      );
      },
    );
  }

  Widget _buildFABs() {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'upload_fab',
        onPressed: _openUploadPage,
        backgroundColor: Colors.blue,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.cloud_upload_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final allSelected = _selectedFiles.length == _files.length &&
        _selectedFolders.length == _folders.length &&
        (_files.isNotEmpty || _folders.isNotEmpty);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutExpo,
      bottom: _isSelectionMode ? 100 : -160,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.80),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: textColor, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _selectedFiles.clear();
                            _selectedFolders.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Выбрано: ${_selectedFiles.length + _selectedFolders.length}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedFiles.clear();
                              _selectedFolders.clear();
                            } else {
                              _selectedFiles.addAll(_files.map((f) => f.id));
                              _selectedFolders.addAll(_folders.map((f) => f.id));
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          allSelected ? 'Снять все' : 'Все',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 8),
                // Row 2: Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Favourite
                    _buildActionItem(
                      icon: Icons.star_rounded,
                      label: 'Избранное',
                      iconColor: textColor,
                      textColor: textColor,
                      onTap: () {
                        for (var f in _files.where((e) => _selectedFiles.contains(e.id))) {
                          FavouritesProvider.instance.toggleFavourite(f);
                        }
                        setState(() {
                          _selectedFiles.clear();
                          _selectedFolders.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Добавлено в избранное')),
                        );
                      },
                    ),
                    // Download
                    _buildActionItem(
                      icon: Icons.download_rounded,
                      label: 'Скачать',
                      iconColor: textColor,
                      textColor: textColor,
                      onTap: () {
                        for (var id in _selectedFiles) {
                          final f = _files.firstWhere((e) => e.id == id);
                          _startDownload(f);
                        }
                        setState(() {
                          _selectedFiles.clear();
                          _selectedFolders.clear();
                        });
                      },
                    ),
                    // Move
                    _buildActionItem(
                      icon: Icons.drive_file_move_rounded,
                      label: 'Переместить',
                      iconColor: textColor,
                      textColor: textColor,
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MoveDestinationScreen(
                              selectedFiles: _selectedFiles.toList(),
                              selectedFolders: _selectedFolders.toList(),
                              currentFolderId: _currentFolderId,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() {
                            _selectedFiles.clear();
                            _selectedFolders.clear();
                          });
                          _loadContent();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Успешно перемещено'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                    // Delete
                    _buildActionItem(
                      icon: Icons.delete_rounded,
                      label: 'Удалить',
                      iconColor: Colors.red.shade400,
                      textColor: textColor,
                      onTap: () {
                        _showDeleteConfirmDialog(
                          itemName: '${_selectedFiles.length + _selectedFolders.length} элементов',
                          onConfirm: () async {
                            setState(() => _isLoading = true);
                            try {
                              await HomeRepository().deleteItems(
                                files: _selectedFiles.toList(),
                                folders: _selectedFolders.toList(),
                              );
                              setState(() {
                                _selectedFiles.clear();
                                _selectedFolders.clear();
                              });
                              _loadContent();
                            } catch (e) {
                              setState(() => _isLoading = false);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: cs.surface,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _userName ?? 'User',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        background: Container(color: cs.surface),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: cs.onSurface,
          ),
          onPressed: () {
            ThemeNotifier.instance.toggle();
          },
          tooltip: 'Сменить тему',
        ),
        IconButton(
          icon: Icon(
            _showFavourites ? Icons.star_rounded : Icons.star_border_rounded,
            color: _showFavourites ? Colors.amber : cs.onSurface,
          ),
          onPressed: () => setState(() {
            _showFavourites = !_showFavourites;
            _activeFilter = _FilterType.all;
          }),
          tooltip: 'Избранное',
        ),
        IconButton(
          icon: Icon(
            _isGrid ? Icons.view_list : Icons.grid_view,
            color: cs.onSurface,
          ),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: cs.onSurface),
          onPressed: _loadContent,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                _navigateTo(-1);
                setState(() {
                  _showFavourites = false;
                  _activeFilter = _FilterType.all;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _breadcrumb.isEmpty && !_showFavourites
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.home_rounded,
                      size: 16,
                      color: _breadcrumb.isEmpty && !_showFavourites
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Главная',
                      style: TextStyle(
                        color: _breadcrumb.isEmpty && !_showFavourites
                            ? Colors.blue
                            : Colors.grey,
                        fontWeight: _breadcrumb.isEmpty && !_showFavourites
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showFavourites) ...[
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Избранное',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            for (int i = 0; i < _breadcrumb.length; i++) ...[
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              GestureDetector(
                onTap: () => _navigateTo(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == _breadcrumb.length - 1
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _breadcrumb[i].name,
                    style: TextStyle(
                      color: i == _breadcrumb.length - 1
                          ? Colors.blue
                          : Colors.grey,
                      fontWeight: i == _breadcrumb.length - 1
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStorageInfo() {
    final total = _folders.length + _files.length;
    final favCount = FavouritesProvider.instance.favouriteFiles.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Cloud Storage',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_folders.length} папок · ${_files.length} файлов · всего $total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (favCount > 0)
                GestureDetector(
                  onTap: () => setState(() {
                    _showFavourites = !_showFavourites;
                    _activeFilter = _FilterType.all;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$favCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_storageData.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.cloud_outlined, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${_fmt(_storageData['used_storage'])} из ${_fmt(_storageData['storage_limit'])}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ((_storageData['percent_used'] as num?)?.toDouble() ?? 0) / 100.0,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startDownload(FileModel file) async {
    if (_downloadProgress.containsKey(file.id)) return;
    setState(() {
      _downloadProgress[file.id] = 0.0;
      _downloadReceivedBytes[file.id] = 0;
    });
    try {
      await _downloadRepo.downloadFile(
        fileId: file.id,
        fileName: file.name,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadReceivedBytes[file.id] = received;
            if (total > 0) _downloadProgress[file.id] = received / total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadProgress.remove(file.id);
        _downloadReceivedBytes.remove(file.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл сохранён: ${file.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadProgress.remove(file.id);
        _downloadReceivedBytes.remove(file.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildContent() {
    return SliverList(
      delegate: SliverChildListDelegate([
        if (_showFavourites) ...[
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                'Избранное',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_displayFiles.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _activeFilter != _FilterType.all
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 14,
                        color: _activeFilter != _FilterType.all
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _activeFilter == _FilterType.images
                            ? 'Фото'
                            : _activeFilter == _FilterType.videos
                            ? 'Видео'
                            : 'Фильтр',
                        style: TextStyle(
                          fontSize: 12,
                          color: _activeFilter != _FilterType.all
                              ? Colors.blue
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        if (_displayFolders.isNotEmpty) ...[
          _buildSectionHeader(
            'Папки',
            Icons.folder_rounded,
            _displayFolders.length,
            trailing: IconButton(
              icon: const Icon(
                Icons.create_new_folder_outlined,
                color: Colors.blue,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _showCreateFolderDialog,
            ),
          ),
          // Pinned folders row (between header and grid/list)
          if (!_showFavourites && _pinnedFolders.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPinnedFolders(),
          ],
          const SizedBox(height: 8),
          _isGrid ? _buildFoldersGrid() : _buildFoldersList(),
          const SizedBox(height: 20),
        ],
        // If folders are empty, still show the + button in a standalone header
        if (_displayFolders.isEmpty && !_showFavourites) ...[
          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.create_new_folder_outlined,
                  color: Colors.blue,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _showCreateFolderDialog,
              ),
            ],
          ),
          // Pinned folders row even when no folders yet
          if (!_showFavourites && _pinnedFolders.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPinnedFolders(),
          ],
          const SizedBox(height: 8),
        ],
        if (_displayFiles.isNotEmpty) ...[
          if (!_showFavourites)
            _buildSectionHeader(
              'Файлы',
              Icons.insert_drive_file,
              _displayFiles.length,
            ),
          const SizedBox(height: 8),
          if (_isGrid && !_showFavourites)
            _buildFilesGrid()
          else
            _buildFilesList(),
        ],
      ]),
    );
  }

  Widget _buildPinnedFolders() {
    if (_pinnedFolders.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _pinnedFolders.length,
        itemBuilder: (context, index) {
          final pin = _pinnedFolders[index];
          final folder = pin['folder'] as FolderModel;
          final pinId = pin['pinId'] as String;
          return GestureDetector(
            onTap: () => _openFolder(folder),
            onLongPress: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: cs.surface,
                  title: Text('Открепить папку?', style: TextStyle(color: cs.onSurface)),
                  content: Text(folder.name, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _unpinFolder(pinId);
                      },
                      child: const Text('Открепить',
                        style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.push_pin, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    folder.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _displayFiles.length,
      itemBuilder: (_, i) {
        final f = _displayFiles[i];
        return _FileGridCard(
          file: f,
          isSelected: _selectedFiles.contains(f.id),
          isSelectionMode: _isSelectionMode,
          previewUrl: _previewUrls[f.id],
          onTap: () {
            if (_isSelectionMode) {
              _toggleFileSelection(f.id);
            } else {
              _openFileViewer(f);
            }
          },
          onSelectTap: () => _toggleFileSelection(f.id),
          onMenuTap: () => _showFileMenu(f),
          onFavouriteTap: () => FavouritesProvider.instance.toggleFavourite(f),
        );
      },
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: [
        ..._displayFiles.map(
          (f) => _FileTile(
            file: f,
            isSelected: _selectedFiles.contains(f.id),
            isSelectionMode: _isSelectionMode,
            authToken: _authToken,
            previewUrl: _previewUrls[f.id],
            onTap: () {
              if (_isSelectionMode) {
                _toggleFileSelection(f.id);
              } else {
                _openFileViewer(f);
              }
            },
            onSelectTap: () => _toggleFileSelection(f.id),
            onMenuTap: () => _showFileMenu(f),
            downloadProgress: _downloadProgress[f.id],
            downloadReceivedBytes: _downloadReceivedBytes[f.id],
            onFavouriteTap: () => FavouritesProvider.instance.toggleFavourite(f),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildFoldersGrid() {
    final totalFolders = _displayFolders.length;
    final maxPage = totalFolders == 0 ? 0 : ((totalFolders - 1) / 4).floor();
    if (_folderPage > maxPage) _folderPage = maxPage;
    if (_folderPage < 0) _folderPage = 0;
    
    final start = _folderPage * 4;
    final end = (start + 4) > totalFolders ? totalFolders : start + 4;
    final pageFolders = _displayFolders.sublist(start, end);

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: pageFolders.length,
          itemBuilder: (_, i) {
            final folder = pageFolders[i];
            return _FolderCard(
              folder: folder,
              isSelected: _selectedFolders.contains(folder.id),
              isSelectionMode: _isSelectionMode,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleFolderSelection(folder.id);
                } else {
                  _openFolder(folder);
                }
              },
              onSelectTap: () => _toggleFolderSelection(folder.id),
              onMenuTap: () => _showFolderMenu(folder),
            );
          },
        ),
        if (totalFolders > 4)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildPaginationRow(
              page: _folderPage,
              isLastPage: (_folderPage + 1) * 4 >= totalFolders,
              onPageChanged: (newPage) => setState(() => _folderPage = newPage),
            ),
          ),
      ],
    );
  }

  Widget _buildFoldersList() {
    final totalFolders = _displayFolders.length;
    final maxPage = totalFolders == 0 ? 0 : ((totalFolders - 1) / 4).floor();
    if (_folderPage > maxPage) _folderPage = maxPage;
    if (_folderPage < 0) _folderPage = 0;
    
    final start = _folderPage * 4;
    final end = (start + 4) > totalFolders ? totalFolders : start + 4;
    final pageFolders = _displayFolders.sublist(start, end);

    return Column(
      children: [
        ...pageFolders.map(
          (f) => _FolderListTile(
            folder: f,
            isSelected: _selectedFolders.contains(f.id),
            isSelectionMode: _isSelectionMode,
            onTap: () {
              if (_isSelectionMode) {
                _toggleFolderSelection(f.id);
              } else {
                _openFolder(f);
              }
            },
            onSelectTap: () => _toggleFolderSelection(f.id),
            onMenuTap: () => _showFolderMenu(f),
          ),
        ),
        if (totalFolders > 4)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildPaginationRow(
              page: _folderPage,
              isLastPage: (_folderPage + 1) * 4 >= totalFolders,
              onPageChanged: (newPage) => setState(() => _folderPage = newPage),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadContent,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.folder_open, size: 40, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            'Здесь пока пусто',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте папку или загрузите фото / видео',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFavourites() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.star_border_rounded,
              size: 40,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет избранных файлов',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите ★ на файле чтобы добавить',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1A73E8)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Folder Grid Card ──────────────────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final FolderModel folder;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onSelectTap;
  final VoidCallback onMenuTap;

  const _FolderCard({
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onSelectTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelectionMode ? onSelectTap : onTap,
      onLongPress: onSelectTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.folder_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!isSelectionMode)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 22,
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onPressed: onMenuTap,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              folder.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Folder List Tile ──────────────────────────────────────────────────────────
class _FolderListTile extends StatelessWidget {
  final FolderModel folder;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onSelectTap;
  final VoidCallback onMenuTap;

  const _FolderListTile({
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onSelectTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(left: BorderSide(color: Colors.blue, width: 3))
              : null,
        ),
        child: ListTile(
          onTap: isSelectionMode ? onSelectTap : onTap,
          onLongPress: onSelectTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: isSelectionMode
              ? InkWell(
                  onTap: onSelectTap,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelectTap(),
                    shape: const CircleBorder(),
                    activeColor: Colors.blue,
                  ),
                )
              : Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
          title: Text(
            folder.name,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing: isSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.grey,
                    size: 22,
                  ),
                  onPressed: onMenuTap,
                ),
        ),
      ),
    );
  }
}

// ── File Tile ─────────────────────────────────────────────────────────────────
class _FileTile extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onMenuTap;
  final double? downloadProgress;
  final int? downloadReceivedBytes;
  final VoidCallback? onFavouriteTap;
  final String? authToken;
  final String? previewUrl;
  final VoidCallback? onTap;
  final VoidCallback? onSelectTap;

  const _FileTile({
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onMenuTap,
    this.downloadProgress,
    this.downloadReceivedBytes,
    this.onFavouriteTap,
    this.authToken,
    this.previewUrl,
    this.onTap,
    this.onSelectTap,
  });

  bool get _isDownloading => downloadProgress != null;

  IconData _icon(String mime) {
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.videocam_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _color(String mime) {
    if (mime.startsWith('image/')) return const Color(0xFF34A853);
    if (mime.startsWith('video/')) return const Color(0xFFEA4335);
    return const Color(0xFF1A73E8);
  }

  Widget _buildLeading(Color color) {
    final mime = file.mimeType.toLowerCase();
    final thumb = file.thumbnailPath;
    // Any file with a thumbnail — show it
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => _iconBox(color),
                errorWidget: (_, __, ___) => _iconBox(color),
              ),
              if (mime.startsWith('video/'))
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // Video without thumbnail — icon with play badge
    if (mime.startsWith('video/')) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.videocam_rounded, color: color, size: 20),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _iconBox(color);
  }

  Widget _iconBox(Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_icon(file.mimeType), color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(file.mimeType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(left: BorderSide(color: Colors.blue, width: 3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: isSelectionMode ? onSelectTap : onTap,
              onLongPress: onSelectTap,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: isSelectionMode
                  ? InkWell(
                      onTap: onSelectTap,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onSelectTap?.call(),
                        shape: const CircleBorder(),
                        activeColor: Colors.blue,
                      ),
                    )
                  : _isDownloading
                  ? SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: downloadProgress,
                            strokeWidth: 3,
                            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF1A73E8),
                            ),
                          ),
                          Text(
                            '${((downloadProgress ?? 0) * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildLeading(color),
              title: Text(
                file.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _isDownloading
                  ? Text(
                      '${DownloadRepository.formatBytes(downloadReceivedBytes ?? 0)} / ${file.formattedSize}',
                      style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontSize: 12,
                      ),
                    )
                  : Text(
                      file.formattedSize,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
                    ),
              trailing: isSelectionMode
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onFavouriteTap,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              file.isFavourite
                                  ? Icons.star
                                  : Icons.star_border,
                              color: file.isFavourite
                                  ? Colors.amber
                                  : Colors.grey,
                              size: 22,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.grey,
                            size: 22,
                          ),
                          onPressed: onMenuTap,
                        ),
                      ],
                    ),
            ),
            if (_isDownloading)
              LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 3,
                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1A73E8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── File Grid Card ────────────────────────────────────────────────────────
class _FileGridCard extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool isSelectionMode;
  final String? previewUrl;
  final VoidCallback onTap;
  final VoidCallback onSelectTap;
  final VoidCallback onMenuTap;
  final VoidCallback onFavouriteTap;

  const _FileGridCard({
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onSelectTap,
    required this.onMenuTap,
    required this.onFavouriteTap,
    this.previewUrl,
  });

  IconData _icon(String mime) {
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.videocam_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _color(String mime) {
    if (mime.startsWith('image/')) return const Color(0xFF34A853);
    if (mime.startsWith('video/')) return const Color(0xFFEA4335);
    return const Color(0xFF1A73E8);
  }

  @override
  Widget build(BuildContext context) {
    final mime = file.mimeType.toLowerCase();
    final color = _color(mime);
    final thumb = file.thumbnailPath;
    final hasPreview = thumb != null && thumb.isNotEmpty;

    return GestureDetector(
      onTap: isSelectionMode ? onSelectTap : onTap,
      onLongPress: onSelectTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: hasPreview
                        ? CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: color.withValues(alpha: 0.08),
                              child: Icon(_icon(mime), color: color, size: 40),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: color.withValues(alpha: 0.08),
                              child: Icon(_icon(mime), color: color, size: 40),
                            ),
                          )
                        : Container(
                            color: color.withValues(alpha: 0.08),
                            child: Center(
                              child: Icon(_icon(mime), color: color, size: 40),
                            ),
                          ),
                  ),
                  // Video play overlay
                  if (mime.startsWith('video/') && hasPreview)
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  // Selection check
                  if (isSelected)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  // ★ star icon
                  if (!isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onFavouriteTap,
                        child: Icon(
                          file.isFavourite ? Icons.star : Icons.star_border,
                          color: file.isFavourite ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info row
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSelectionMode)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onPressed: onMenuTap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
