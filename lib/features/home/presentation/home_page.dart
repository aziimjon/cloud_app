import 'package:flutter/material.dart';
import '../data/home_repository.dart';
import '../data/download_repository.dart';
import '../data/models/folder_model.dart';
import '../data/models/file_model.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/config/app_config.dart';
import '../../upload/presentation/upload_page.dart';

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

  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  bool _isLoading = true;
  String? _error;
  bool _isGrid = true;
  String? _userName;
  String? _authToken;

  final Map<String, double> _downloadProgress = {};
  final Map<String, int> _downloadReceivedBytes = {};

  final List<({String id, String name})> _breadcrumb = [];

  bool _showFavourites = false;
  _FilterType _activeFilter = _FilterType.all;

  String? get _currentFolderId =>
      _breadcrumb.isEmpty ? null : _breadcrumb.last.id;

  List<FileModel> get _favouriteFiles =>
      _files.where((f) => f.isFavourite).toList();

  List<FileModel> get _displayFiles {
    final source = _showFavourites ? _favouriteFiles : _files;
    if (_activeFilter == _FilterType.all) return source;
    return source.where((f) => _matchesFilter(f, _activeFilter)).toList();
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

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadContent();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final token = await SecureStorage.getAccessToken();
    if (mounted) setState(() => _authToken = token);
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.getContent(parentId: _currentFolderId);
      if (!mounted) return;
      setState(() {
        _folders = result['folders'] as List<FolderModel>;
        _files = result['files'] as List<FileModel>;
        _isLoading = false;
      });
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
    });
    widget.onFolderChanged?.call(folder.id);
    _loadContent();
  }

  void _navigateTo(int index) {
    if (index < 0) {
      if (_breadcrumb.isEmpty) return;
      setState(() => _breadcrumb.clear());
      widget.onFolderChanged?.call(null);
    } else {
      if (index == _breadcrumb.length - 1) return;
      setState(() => _breadcrumb.removeRange(index + 1, _breadcrumb.length));
      widget.onFolderChanged?.call(_breadcrumb[index].id);
    }
    _loadContent();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: Colors.grey[300],
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
      ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                decoration: InputDecoration(
                  hintText: 'Название папки',
                  filled: true,
                  fillColor: Colors.grey[100],
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
      ),
    );
  }

  void _showFolderMenu(FolderModel folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.blue),
                title: const Text('Открыть'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFolder(folder);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.drive_file_rename_outline,
                  color: Colors.orange,
                ),
                title: const Text('Переименовать'),
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
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showFileMenu(FileModel file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
                      Icons.insert_drive_file_rounded,
                      color: Color(0xFF1A73E8),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  file.isFavourite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: file.isFavourite ? Colors.amber : Colors.grey,
                ),
                title: Text(
                  file.isFavourite ? 'Убрать из избранного' : 'В избранное',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleFavouriteLocal(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text('Скачать'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDownload(file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.drive_file_rename_outline,
                  color: Colors.orange,
                ),
                title: const Text('Переименовать'),
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
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
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
      ),
    );
  }

  // ✅ ФИК #2: используем favouriteId (int) для удаления, не file.id (uuid)
  Future<void> _toggleFavouriteLocal(FileModel file) async {
    final index = _files.indexWhere((f) => f.id == file.id);
    if (index == -1) return;

    final wasInFavourites = file.isFavourite;

    // Мгновенно обновляем UI
    setState(() {
      _files[index] = file.copyWith(isFavourite: !wasInFavourites);
    });

    try {
      if (wasInFavourites) {
        // ✅ ИСПРАВЛЕНО: нужен favouriteId (integer record id), не file.id (uuid)
        final favId = file.favouriteId;
        if (favId == null) {
          // Если favouriteId не сохранён в модели — загружаем список избранного
          // и ищем нужный record id
          final favList = await _repo.getFavouriteFiles();
          final record = favList.firstWhere(
            (f) => f['file']?['id']?.toString() == file.id,
            orElse: () => <String, dynamic>{},
          );
          final resolvedId = record['id']?.toString();
          if (resolvedId == null) {
            // Не нашли — откатываем UI
            if (!mounted) return;
            setState(() => _files[index] = file);
            return;
          }
          await _repo.removeFromFavourites(resolvedId);
        } else {
          await _repo.removeFromFavourites(favId);
        }
        // После удаления сбрасываем favouriteId в модели
        if (!mounted) return;
        setState(() {
          _files[index] = _files[index].copyWith(
            isFavourite: false,
            favouriteId: null,
          );
        });
      } else {
        // Добавляем и сохраняем вернувшийся integer record id
        final recordId = await _repo.addToFavourites(file.id);
        if (!mounted) return;
        setState(() {
          _files[index] = _files[index].copyWith(
            isFavourite: true,
            favouriteId: recordId.toString(),
          );
        });
      }
    } on AppException catch (e) {
      // Ошибка — откатываем изменение
      if (!mounted) return;
      setState(() => _files[index] = file);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  void _showRenameDialog({
    required String currentName,
    required Future<void> Function(String) onRename,
  }) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Переименовать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Новое название',
            filled: true,
            fillColor: Colors.grey[100],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить?'),
        content: Text(
          'Вы уверены, что хотите удалить «$itemName»?\nЭто действие необратимо.',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
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
          else if (_showFavourites && _favouriteFiles.isEmpty)
            SliverFillRemaining(child: _buildEmptyFavourites())
          else if (!_showFavourites &&
              _displayFolders.isEmpty &&
              _displayFiles.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _buildContent(),
            ),
        ],
      ),
      floatingActionButton: _buildFABs(),
    );
  }

  Widget _buildFABs() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
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
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            heroTag: 'create_fab',
            onPressed: _showCreateFolderDialog,
            backgroundColor: Colors.blue,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
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
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _userName ?? 'User',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        background: Container(color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFavourites ? Icons.star_rounded : Icons.star_border_rounded,
            color: _showFavourites ? Colors.amber : Colors.black,
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
            color: Colors.black,
          ),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black),
          onPressed: _loadContent,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      color: Colors.white,
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
    final favCount = _favouriteFiles.length;
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
      child: Row(
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
              const Text(
                'Избранное',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
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
          ),
          const SizedBox(height: 8),
          _isGrid ? _buildFoldersGrid() : _buildFoldersList(),
          const SizedBox(height: 20),
        ],
        if (_displayFiles.isNotEmpty) ...[
          if (!_showFavourites)
            _buildSectionHeader(
              'Файлы',
              Icons.insert_drive_file,
              _displayFiles.length,
            ),
          const SizedBox(height: 8),
          ..._displayFiles.map(
            (f) => _FileTile(
              file: f,
              authToken: _authToken,
              onMenuTap: () => _showFileMenu(f),
              downloadProgress: _downloadProgress[f.id],
              downloadReceivedBytes: _downloadReceivedBytes[f.id],
              onFavouriteTap: () => _toggleFavouriteLocal(f),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black87,
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
      ],
    );
  }

  Widget _buildFoldersGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _displayFolders.length,
      itemBuilder: (_, i) => _FolderCard(
        folder: _displayFolders[i],
        onTap: () => _openFolder(_displayFolders[i]),
        onMenuTap: () => _showFolderMenu(_displayFolders[i]),
      ),
    );
  }

  Widget _buildFoldersList() {
    return Column(
      children: _displayFolders
          .map(
            (f) => _FolderListTile(
              folder: f,
              onTap: () => _openFolder(f),
              onMenuTap: () => _showFolderMenu(f),
            ),
          )
          .toList(),
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
            style: TextStyle(color: Colors.grey[600]),
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
          const Text(
            'Здесь пока пусто',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте папку или загрузите фото / видео',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
          const Text(
            'Нет избранных файлов',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите ★ на файле чтобы добавить',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const _FolderCard({
    required this.folder,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onPressed: onMenuTap,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              folder.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
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
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const _FolderListTile({
    required this.folder,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
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
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
          onPressed: onMenuTap,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── File Tile ─────────────────────────────────────────────────────────────────
class _FileTile extends StatelessWidget {
  final FileModel file;
  final VoidCallback onMenuTap;
  final double? downloadProgress;
  final int? downloadReceivedBytes;
  final VoidCallback? onFavouriteTap;
  final String? authToken;

  const _FileTile({
    required this.file,
    required this.onMenuTap,
    this.downloadProgress,
    this.downloadReceivedBytes,
    this.onFavouriteTap,
    this.authToken,
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
    // Image preview via download endpoint
    if (mime.startsWith('image/') && authToken != null) {
      final url =
          '${AppConfig.instance.baseUrl}content/files/${file.id}/download/';
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          headers: {'Authorization': 'Bearer $authToken'},
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          cacheWidth: 126,
          errorBuilder: (_, __, ___) => _iconBox(color),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _iconBox(color);
          },
        ),
      );
    }
    // Video — icon with play badge
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: _isDownloading
                ? SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: downloadProgress,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey[200],
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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onFavouriteTap,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      file.isFavourite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: file.isFavourite ? Colors.amber : Colors.grey[400],
                      size: 20,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.grey,
                    size: 20,
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
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1A73E8),
              ),
            ),
        ],
      ),
    );
  }
}
