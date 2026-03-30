import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_app/l10n/app_localizations.dart';
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
import '../../../core/network/dio_client.dart';
import '../../share/presentation/bloc/share_bloc.dart';
import '../../share/data/repository/share_repository_impl.dart';
import '../../share/data/remote/share_remote_data_source_impl.dart';
import '../../share/presentation/widgets/share_dialog.dart';
import '../../profile/data/profile_repository.dart';


enum _FilterType { all, images, videos }

class FilesPage extends StatefulWidget {
  final void Function(String? folderId)? onFolderChanged;

  const FilesPage({super.key, this.onFolderChanged});

  @override
  State<FilesPage> createState() => FilesPageState();
}

class FilesPageState extends State<FilesPage> {
  final _repo = HomeRepository();
  final _downloadRepo = DownloadRepository();
  final _profileRepo = ProfileRepository();

  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  bool _isLoading = true;
  String? _error;
  bool _isGrid = true;
  String? _authToken;


  final Map<String, double> _downloadProgress = {};
  final Map<String, int> _downloadReceivedBytes = {};

  final List<({String id, String name, bool isSync})> _breadcrumb = [];

  bool _showFavourites = false;
  _FilterType _activeFilter = _FilterType.all;

  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  bool get _isSelectionMode =>
      _selectedFiles.isNotEmpty || _selectedFolders.isNotEmpty;
  final Set<String> _selectedFiles = {};
  final Set<String> _selectedFolders = {};

  List<Map<String, dynamic>> _pinnedFolders = [];
  int _folderPage = 0;
  int _totalFilesCount = 0;
  late final ShareBloc _shareBloc;
  bool get _isSyncFolder =>
      _breadcrumb.isNotEmpty && _breadcrumb.last.isSync;

  String _fmt(dynamic b) {
    if (b == null) return '0 KB';
    final v = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
    if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(2)} GB';
    if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(1)} MB';
    return '${(v / 1024).toStringAsFixed(0)} KB';
  }

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
        Text('${page + 1}',
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
      if (folder is FolderModel && folder.id == folderId)
        return pin['pinId'] as String?;
    }
    return null;
  }

  Future<void> _pinFolder(FolderModel folder) async {
    final t = AppLocalizations.of(context)!;
    if (_pinnedFolders.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.maxPinnedFolders)),
        );
      }
      return;
    }
    if (_getPinId(folder.id) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.alreadyPinned)),
        );
      }
      return;
    }
    final newPin = {'pinId': folder.id, 'folder': folder};
    setState(() => _pinnedFolders = [..._pinnedFolders, newPin]);
    try {
      await _repo.pinFolder(folder.id);
    } on AppException catch (e) {
      setState(() => _pinnedFolders =
          _pinnedFolders.where((p) => p['pinId'] != folder.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _unpinFolder(String pinId) async {
    final backup = List<Map<String, dynamic>>.from(_pinnedFolders);
    setState(() =>
    _pinnedFolders =
        _pinnedFolders.where((p) => p['pinId'] != pinId).toList());
    try {
      await _repo.unpinFolder(pinId);
    } on AppException catch (e) {
      setState(() => _pinnedFolders = backup);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _toggleFolderSelection(String id) {
    // Sync folder cannot be selected
    if (_folders.any((f) => f.id == id && f.isSync)) return;
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
    final source =
    _showFavourites ? FavouritesProvider.instance.favouriteFiles : _files;
    final syncedSource = source
        .map((f) => f.copyWith(
      isFavourite: FavouritesProvider.instance.isFavourite(f.id),
    ))
        .toList();
    if (_activeFilter == _FilterType.all) return syncedSource;
    return syncedSource
        .where((f) => _matchesFilter(f, _activeFilter))
        .toList();
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
    FavouritesProvider.instance.loadFavourites();
    _loadContent();
    _loadAuthToken();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        if (_hasNextPage && !_isLoadingMore && !_isLoading) {
          _loadMoreContent();
        }
      }
    });
    _shareBloc = ShareBloc(
      ShareRepositoryImpl(
        ShareRemoteDataSourceImpl(DioClient.instance),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shareBloc.close();
    super.dispose();
  }

  Future<void> _loadAuthToken() async {
    final token = await SecureStorage.getAccessToken();
    if (mounted) setState(() => _authToken = token);
  }



  Future<void> _openFileViewer(FileModel file) async {
    final t = AppLocalizations.of(context)!;
    final mime = file.mimeType.toLowerCase();
    if (mime.startsWith('image/')) {
      final fullUrl = await _repo.getPreviewUrl(file.id);
      if (fullUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.couldNotOpenImage)),
          );
        }
        return;
      }
      if (!mounted) return;
      final allImageFiles = _displayFiles
          .where((f) => f.mimeType.toLowerCase().startsWith('image/'))
          .toList();
      final idx = allImageFiles.indexWhere((f) => f.id == file.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoViewerPage(
            files: allImageFiles
                .map((f) => (
            url: f.thumbnailPath ?? '',
            name: f.name,
            fileId: f.id,
            ))
                .toList(),
            initialIndex: idx < 0 ? 0 : idx,
            authToken: _authToken,
            onNeedFullUrl: (fileId) => _repo.getPreviewUrl(fileId),
          ),
        ),
      );
    } else if (mime.startsWith('video/')) {
      final url = await _repo.getPreviewUrl(file.id);
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.couldNotOpenVideo)),
          );
        }
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(
            videoUrl: url,
            fileName: file.name,
            authToken: _authToken,
          ),
        ),
      );
    }
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasNextPage = false;
    });
    try {
      final result = await _repo.getContent(
        parentId: _currentFolderId,
        page: 1,
      );
      List<Map<String, dynamic>> pinned = [];
      try {
        pinned = await _repo.getPinnedFolders();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        final List<FolderModel> loadedFolders = result['folders'] as List<FolderModel>;
        loadedFolders.sort((a, b) => a.isSync ? -1 : (b.isSync ? 1 : 0));
        _folders = loadedFolders;
        _files = result['files'] as List<FileModel>;
        _hasNextPage = result['hasNext'] as bool;
        _pinnedFolders = pinned;
        _totalFilesCount = result['totalCount'] as int? ?? _files.length;
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

  Future<void> _loadMoreContent() async {
    if (!mounted || _isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _repo.getContent(
        parentId: _currentFolderId,
        page: _currentPage + 1,
      );
      if (!mounted) return;
      final newFiles = result['files'] as List<FileModel>;
      setState(() {
        _files.addAll(newFiles);
        _currentPage++;
        _hasNextPage = result['hasNext'] as bool;
        _isLoadingMore = false;
      });

    } on AppException catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void reloadContent() => _loadContent();

  bool handleBackNavigation() {
    if (_breadcrumb.isNotEmpty) {
      setState(() {
        _breadcrumb.removeLast();
        _folderPage = 0;
      });
      widget.onFolderChanged
          ?.call(_breadcrumb.isEmpty ? null : _breadcrumb.last.id);
      _loadContent();
      return true;
    }
    return false;
  }

  void toggleFavourites() {
    setState(() {
      _showFavourites = true;
      _activeFilter = _FilterType.all;
    });
  }

  void _openUploadPage() {
    final currentFolder = _currentFolderId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadPage(
          parentId: currentFolder,
          onUploadComplete: () async {
            await Future.delayed(const Duration(seconds: 2));
            _loadContent();
          },
        ),
      ),
    ).then((_) => _loadContent());
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.media,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    final currentFolder = _currentFolderId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadPage(
          parentId: currentFolder,
          initialFiles: result.files,
          onUploadComplete: () async {
            await Future.delayed(const Duration(seconds: 2));
            _loadContent();
          },
        ),
      ),
    ).then((_) => _loadContent());
  }

  void _openFolder(FolderModel folder) {
    setState(() {
      _breadcrumb.add((id: folder.id, isSync: false, name: folder.name));
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
        final t = AppLocalizations.of(ctx)!;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
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
                Text(t.filter,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FilterChip(
                      label: t.all,
                      icon: Icons.apps_rounded,
                      isActive: _activeFilter == _FilterType.all,
                      onTap: () {
                        setState(() => _activeFilter = _FilterType.all);
                        Navigator.pop(ctx);
                      },
                    ),
                    _FilterChip(
                      label: t.photos,
                      icon: Icons.image_rounded,
                      isActive: _activeFilter == _FilterType.images,
                      onTap: () {
                        setState(() => _activeFilter = _FilterType.images);
                        Navigator.pop(ctx);
                      },
                    ),
                    _FilterChip(
                      label: t.videos,
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
    final t = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
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
                      child: const Icon(Icons.create_new_folder,
                          color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(t.newFolder,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: t.folderName,
                    hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: Colors.blue, width: 1.5),
                    ),
                    prefixIcon:
                    const Icon(Icons.folder, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(t.cancel),
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
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(t.create,
                            style: const TextStyle(color: Colors.white)),
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

  void _showInfoDialog({
    required String id,
    required String type,
    required String name,
    required String previewUrl,
    required Color iconColor,
    required IconData icon,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _InfoBottomSheet(
        id: id,
        type: type,
        name: name,
        previewUrl: previewUrl,
        iconColor: iconColor,
        icon: icon,
        fetchInfo: () => _profileRepo.getContentInfo(id: id, type: type),
        fmt: _fmt,
      ),
    );
  }

  void _showFolderMenu(FolderModel folder) {
    final t = AppLocalizations.of(context)!;
    final isSyncF = folder.isSync;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
                      horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_rounded,
                          color: Colors.amber, size: 24),
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
                  title: t.open,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFolder(folder);
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.info_outline_rounded,
                  color: Colors.blueGrey,
                  title: t.details,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showInfoDialog(
                      id: folder.id,
                      type: 'folder',
                      name: folder.name,
                      previewUrl: '',
                      iconColor: Colors.amber,
                      icon: Icons.folder_rounded,
                    );
                  },
                ),
                if (!isSyncF) ...[
                  _buildBottomSheetItem(
                    icon: Icons.share_rounded,
                    color: Colors.green,
                    title: t.share,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showShareDialog(fileIds: [], folderIds: [folder.id]);
                    },
                  ),
                  _buildBottomSheetItem(
                    icon: Icons.drive_file_rename_outline,
                    color: Colors.orange,
                    title: t.rename,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameDialog(
                        currentName: folder.name,
                        onRename: (newName) async {
                          try {
                            await _repo.renameItem(
                                type: 'folder', id: folder.id, name: newName);
                            if (!mounted) return;
                            _loadContent();
                          } on AppException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e.message),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                      );
                    },
                  ),
                  _buildBottomSheetItem(
                    icon: Icons.arrow_forward_rounded,
                    color: Colors.blue,
                    title: t.move,
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
                          SnackBar(
                            content: Text(t.successfullyMoved),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                  _buildBottomSheetItem(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    title: t.delete,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showDeleteConfirmDialog(
                        itemName: folder.name,
                        onConfirm: () async {
                          try {
                            await _repo.deleteItem(
                                type: 'folder', id: folder.id);
                            if (!mounted) return;
                            _loadContent();
                          } on AppException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e.message),
                                  backgroundColor: Colors.red),
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
                        title: isPinned ? t.unpinLabel : t.pinLabel,
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
                if (isSyncF)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: Center(
                      child: Text(
                        'Sync folder · managed automatically',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
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
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
                      horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _color(file.mimeType).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_icon(file.mimeType),
                            color: _color(file.mimeType), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              file.formattedSize,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
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
                      ? t.removeFromFavourites
                      : t.addToFavourites,
                  onTap: () {
                    Navigator.pop(ctx);
                    FavouritesProvider.instance.toggleFavourite(file);
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.download_rounded,
                  color: Colors.blue,
                  title: t.download,
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDownload(file);
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.remove_red_eye_outlined,
                  color: Colors.purple,
                  title: t.preview,
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFileViewer(file);
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.info_outline_rounded,
                  color: Colors.blueGrey,
                  title: t.details,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showInfoDialog(
                      id: file.id,
                      type: 'file',
                      name: file.name,
                      previewUrl: file.thumbnailPath ?? '',
                      iconColor: _color(file.mimeType),
                      icon: _icon(file.mimeType),
                    );
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.drive_file_rename_outline,
                  color: Colors.orange,
                  title: t.rename,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(
                      currentName: file.name,
                      onRename: (newName) async {
                        try {
                          await _repo.renameItem(
                              type: 'file', id: file.id, name: newName);
                          if (!mounted) return;
                          _loadContent();
                        } on AppException catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red),
                          );
                        }
                      },
                    );
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.arrow_forward_rounded,
                  color: Colors.blue,
                  title: t.move,
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
                        SnackBar(
                          content: Text(t.successfullyMoved),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.share_rounded,
                  color: Colors.green,
                  title: t.share,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showShareDialog(fileIds: [file.id], folderIds: []);
                  },
                ),
                _buildBottomSheetItem(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  title: t.delete,
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
                                backgroundColor: Colors.red),
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
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surface,
        title: Text(t.rename, style: TextStyle(color: cs.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: t.newNameHint,
            hintStyle:
            TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
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
            child: Text(t.cancel),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
            Text(t.save, style: const TextStyle(color: Colors.white)),
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
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.surface,
        title: Text(t.deleteConfirm, style: TextStyle(color: cs.onSurface)),
        content: Text(
          t.deleteConfirmMessage(itemName),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
            Text(t.delete, style: const TextStyle(color: Colors.white)),
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
        return PopScope(
          canPop: _breadcrumb.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _breadcrumb.isNotEmpty) {
              setState(() {
                _breadcrumb.removeLast();
                _folderPage = 0;
              });
              widget.onFolderChanged?.call(
                  _breadcrumb.isEmpty ? null : _breadcrumb.last.id);
              _loadContent();
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadContent,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    slivers: [
                      _buildAppBar(),
                      SliverToBoxAdapter(child: _buildBreadcrumb()),
                      if (_isLoading)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        SliverFillRemaining(child: _buildError())
                      else if (FavouritesProvider.instance.isLoading &&
                            _showFavourites)
                          const SliverFillRemaining(
                            child:
                            Center(child: CircularProgressIndicator()),
                          )
                        else if (_showFavourites &&
                              FavouritesProvider
                                  .instance.favouriteFiles.isEmpty)
                            SliverFillRemaining(
                                child: _buildEmptyFavourites())
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
                                    bottom: 160),
                                sliver: SliverMainAxisGroup(
                                  slivers: _buildContentSlivers(),
                                ),
                              ),
                    ],
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
            floatingActionButton: _buildFABs(),
          ),
        );
      },
    );
  }

  Widget _buildFABs() {
    if (_isSelectionMode || _isSyncFolder) return const SizedBox.shrink();
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'upload_fab',
        onPressed: _openUploadPage,
        backgroundColor: Colors.blue,
        elevation: 4,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.cloud_upload_rounded,
            color: Colors.white, size: 26),
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
    final t = AppLocalizations.of(context)!;
    final allSelected = _selectedFiles.length == _files.length &&
        _selectedFolders.length == _folders.length &&
        (_files.isNotEmpty || _folders.isNotEmpty);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutExpo,
      bottom: _isSelectionMode ? 16 : -160,
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
            padding: const EdgeInsets.only(
                left: 8, right: 8, top: 10, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        t.selectedCount(_selectedFiles.length +
                            _selectedFolders.length),
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
                              _selectedFiles
                                  .addAll(_files.map((f) => f.id));
                              _selectedFolders
                                  .addAll(_folders
                                      .where((f) => !f.isSync)
                                      .map((f) => f.id));
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          allSelected ? t.deselectAll : t.selectAll,
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionItem(
                      icon: Icons.star_rounded,
                      label: t.favourite,
                      iconColor: textColor,
                      textColor: textColor,
                      onTap: () {
                        for (var f in _files.where(
                                (e) => _selectedFiles.contains(e.id))) {
                          FavouritesProvider.instance.toggleFavourite(f);
                        }
                        setState(() {
                          _selectedFiles.clear();
                          _selectedFolders.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.addedToFavourites)),
                        );
                      },
                    ),
                    _buildActionItem(
                      icon: Icons.download_rounded,
                      label: t.download,
                      iconColor: textColor,
                      textColor: textColor,
                      onTap: () {
                        for (var id in _selectedFiles) {
                          final f =
                          _files.firstWhere((e) => e.id == id);
                          _startDownload(f);
                        }
                        setState(() {
                          _selectedFiles.clear();
                          _selectedFolders.clear();
                        });
                      },
                    ),
                    _buildActionItem(
                      icon: Icons.share_rounded,
                      label: t.share,
                      iconColor: Colors.green,
                      textColor: textColor,
                      onTap: () {
                        final fileIds = _selectedFiles.toList();
                        final folderIds = _selectedFolders
                            .where((id) => !_folders.any((f) => f.id == id && f.isSync))
                            .toList();
                        setState(() {
                          _selectedFiles.clear();
                          _selectedFolders.clear();
                        });
                        _showShareDialog(
                            fileIds: fileIds, folderIds: folderIds);
                      },
                    ),
                    _buildActionItem(
                      icon: Icons.drive_file_move_rounded,
                      label: t.move,
                      iconColor: textColor,
                      textColor: textColor,
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MoveDestinationScreen(
                              selectedFiles: _selectedFiles.toList(),
                              selectedFolders: _selectedFolders
                                  .where((id) => !_folders.any((f) => f.id == id && f.isSync))
                                  .toList(),
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
                            SnackBar(
                              content: Text(t.successfullyMoved),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                    _buildActionItem(
                      icon: Icons.delete_rounded,
                      label: t.delete,
                      iconColor: Colors.red.shade400,
                      textColor: textColor,
                      onTap: () {
                        _showDeleteConfirmDialog(
                          itemName: t.deleteItems(_selectedFiles.length +
                              _selectedFolders.length),
                          onConfirm: () async {
                            setState(() => _isLoading = true);
                            try {
                              await HomeRepository().deleteItems(
                                files: _selectedFiles.toList(),
                                folders: _selectedFolders
                                    .where((id) => !_folders.any((f) => f.id == id && f.isSync))
                                    .toList(),
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
    final t = AppLocalizations.of(context)!;
    return SliverAppBar(
      expandedHeight: 60,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: cs.surface,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Text(
          t.files,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        background: Container(color: cs.surface),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFavourites
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: _showFavourites ? Colors.amber : cs.onSurface,
          ),
          onPressed: () => setState(() {
            _showFavourites = !_showFavourites;
            _activeFilter = _FilterType.all;
          }),
          tooltip: t.favourites,
        ),
        IconButton(
          icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view,
              color: cs.onSurface),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: cs.onSurface),
          onPressed: _loadContent,
          tooltip: t.refresh,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    final t = AppLocalizations.of(context)!;
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
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _breadcrumb.isEmpty && !_showFavourites
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home_rounded,
                        size: 16,
                        color: _breadcrumb.isEmpty && !_showFavourites
                            ? Colors.blue
                            : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      t.home_breadcrumb,
                      style: TextStyle(
                        color: _breadcrumb.isEmpty && !_showFavourites
                            ? Colors.blue
                            : Colors.grey,
                        fontWeight:
                        _breadcrumb.isEmpty && !_showFavourites
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
              const Icon(Icons.chevron_right,
                  size: 16, color: Colors.grey),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(t.favourites_breadcrumb,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ],
            for (int i = 0; i < _breadcrumb.length; i++) ...[
              const Icon(Icons.chevron_right,
                  size: 16, color: Colors.grey),
              GestureDetector(
                onTap: () => _navigateTo(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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

  Future<void> _startDownload(FileModel file) async {
    final t = AppLocalizations.of(context)!;
    if (_downloadProgress.containsKey(file.id)) return;
    setState(() {
      _downloadProgress[file.id] = 0.0;
      _downloadReceivedBytes[file.id] = 0;
    });
    try {
      await _downloadRepo.downloadFile(
        fileId: file.id,
        fileName: file.name,
        mimeType: file.mimeType,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadReceivedBytes[file.id] = received;
            if (total > 0)
              _downloadProgress[file.id] = received / total;
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
          content: Text(t.fileSaved(file.name)),
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

  void _showShareDialog({
    required List<String> fileIds,
    required List<String> folderIds,
  }) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: _shareBloc,
        child: ShareDialog(
          initialFileIds: fileIds,
          initialFolderIds: folderIds,
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers() {
    final t = AppLocalizations.of(context)!;
    // ── Header & folders section (non-virtualized, small content) ──
    final headerChildren = <Widget>[];

    // ── Sync folder info banner ──
    if (_isSyncFolder) {
      headerChildren.add(Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: Colors.blue.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.syncFolderReadOnly,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    if (_showFavourites) {
      headerChildren.add(Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 6),
          Text(
            t.favourites_breadcrumb,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _activeFilter != _FilterType.all
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 14,
                      color: _activeFilter != _FilterType.all
                          ? Colors.blue
                          : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _activeFilter == _FilterType.images
                        ? t.photos
                        : _activeFilter == _FilterType.videos
                        ? t.videos
                        : t.filter,
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
      ));
      headerChildren.add(const SizedBox(height: 12));
    }

    if (_displayFolders.isNotEmpty) {
      headerChildren.add(_buildSectionHeader(
          t.folders, Icons.folder_rounded, _displayFolders.length,
          trailing: _isSyncFolder
              ? null
              : IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined,
                      color: Colors.blue, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showCreateFolderDialog,
                )));
      if (!_showFavourites && _pinnedFolders.isNotEmpty) {
        headerChildren.add(const SizedBox(height: 8));
        headerChildren.add(_buildPinnedFolders());
      }
      headerChildren.add(const SizedBox(height: 8));
      headerChildren.add(_isGrid ? _buildFoldersGrid() : _buildFoldersList());
      headerChildren.add(const SizedBox(height: 20));
    } else if (!_showFavourites) {
      headerChildren.add(_buildSectionHeader(
          t.folders, Icons.folder_rounded, 0,
          trailing: _isSyncFolder
              ? null
              : IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined,
                      color: Colors.blue, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showCreateFolderDialog,
                )));
      if (_pinnedFolders.isNotEmpty) {
        headerChildren.add(const SizedBox(height: 8));
        headerChildren.add(_buildPinnedFolders());
      }
      headerChildren.add(const SizedBox(height: 8));
    }

    if (_displayFiles.isNotEmpty && !_showFavourites) {
      headerChildren.add(_buildSectionHeader(
          t.files, Icons.insert_drive_file, _totalFilesCount));
      headerChildren.add(const SizedBox(height: 8));
    }

    final slivers = <Widget>[];

    // ── 1. Header sliver (folders, section headers) ──
    if (headerChildren.isNotEmpty) {
      slivers.add(SliverList(
        delegate: SliverChildListDelegate(headerChildren),
      ));
    }

    // ── 2. Files sliver (virtualized) ──
    if (_displayFiles.isNotEmpty) {
      if (_isGrid && !_showFavourites) {
        slivers.add(_buildFilesGridSliver());
      } else {
        slivers.add(_buildFilesListSliver());
      }
    }

    // ── 3. Loading more indicator ──
    if (_isLoadingMore) {
      slivers.add(const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ));
    }

    return slivers;
  }

  Widget _buildPinnedFolders() {
    if (_pinnedFolders.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
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
              // Prevent unpin for sync folder
              if (folder.isSync) return;
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: cs.surface,
                  title: Text(t.unpinFolder,
                      style: TextStyle(color: cs.onSurface)),
                  content: Text(folder.name,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.7))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _unpinFolder(pinId);
                      },
                      child: Text(t.unpin,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(folder.isSync ? Icons.sync_rounded : Icons.push_pin,
                      size: 14, color: Colors.blue),
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

  Widget _buildFilesGridSliver() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final f = _displayFiles[i];
          return RepaintBoundary(
            child: _FileGridCard(
              key: ValueKey(f.id),
              file: f,
              isSelected: _selectedFiles.contains(f.id),
              isSelectionMode: _isSelectionMode,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleFileSelection(f.id);
                } else {
                  _openFileViewer(f);
                }
              },
              onSelectTap: () => _toggleFileSelection(f.id),
              onMenuTap: () => _showFileMenu(f),
              onFavouriteTap: () =>
                  FavouritesProvider.instance.toggleFavourite(f),
            ),
          );
        },
        childCount: _displayFiles.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
    );
  }

  Widget _buildFilesListSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final f = _displayFiles[i];
          return RepaintBoundary(
            child: _FileTile(
              key: ValueKey(f.id),
              file: f,
              isSelected: _selectedFiles.contains(f.id),
              isSelectionMode: _isSelectionMode,
              authToken: _authToken,
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
              onFavouriteTap: () =>
                  FavouritesProvider.instance.toggleFavourite(f),
            ),
          );
        },
        childCount: _displayFiles.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count,
      {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon,
            size: 18,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5)),
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
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _buildFoldersGrid() {
    final totalFolders = _displayFolders.length;
    final maxPage =
    totalFolders == 0 ? 0 : ((totalFolders - 1) / 4).floor();
    if (_folderPage > maxPage) _folderPage = maxPage;
    if (_folderPage < 0) _folderPage = 0;
    final start = _folderPage * 4;
    final end =
    (start + 4) > totalFolders ? totalFolders : start + 4;
    final pageFolders = _displayFolders.sublist(start, end);
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
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
              isSyncFolder: folder.isSync,
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
              onPageChanged: (p) =>
                  setState(() => _folderPage = p),
            ),
          ),
      ],
    );
  }

  Widget _buildFoldersList() {
    final totalFolders = _displayFolders.length;
    final maxPage =
    totalFolders == 0 ? 0 : ((totalFolders - 1) / 4).floor();
    if (_folderPage > maxPage) _folderPage = maxPage;
    if (_folderPage < 0) _folderPage = 0;
    final start = _folderPage * 4;
    final end =
    (start + 4) > totalFolders ? totalFolders : start + 4;
    final pageFolders = _displayFolders.sublist(start, end);
    return Column(
      children: [
        ...pageFolders.map(
              (f) => _FolderListTile(
            folder: f,
            isSelected: _selectedFolders.contains(f.id),
            isSelectionMode: _isSelectionMode,
            isSyncFolder: f.isSync,
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
              onPageChanged: (p) =>
                  setState(() => _folderPage = p),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadContent,
            icon: const Icon(Icons.refresh),
            label: Text(t.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final t = AppLocalizations.of(context)!;
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
            child:
            const Icon(Icons.folder_open, size: 40, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            t.emptyFolder,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.emptyFolderSubtitle,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showCreateFolderDialog,
                    icon: const Icon(
                        Icons.create_new_folder_rounded,
                        color: Colors.blue),
                    label: Text(t.createFolder,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )),
                    style: OutlinedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                          color: Colors.blue, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickAndUploadFiles,
                    icon: const Icon(Icons.cloud_upload_rounded,
                        color: Colors.white),
                    label: Text(t.uploadFiles,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFavourites() {
    final t = AppLocalizations.of(context)!;
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
            child: const Icon(Icons.star_border_rounded,
                size: 40, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            t.noFavourites,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.noFavouritesSubtitle,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 13),
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
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1A73E8)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive ? Colors.white : Colors.grey[600]),
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
  final bool isSyncFolder;
  final VoidCallback onTap;
  final VoidCallback onSelectTap;
  final VoidCallback onMenuTap;

  const _FolderCard({
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    this.isSyncFolder = false,
    required this.onTap,
    required this.onSelectTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final folderColor = isSyncFolder ? Colors.blue : Colors.amber;
    return RepaintBoundary(child: GestureDetector(
      onTap: isSelectionMode
          ? (isSyncFolder ? null : onSelectTap)
          : onTap,
      onLongPress: isSyncFolder ? null : onSelectTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border:
          isSelected ? Border.all(color: Colors.blue, width: 2) : null,
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
                        color: folderColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.folder_rounded,
                          color: folderColor, size: 22),
                    ),
                    if (isSyncFolder)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sync_rounded,
                              color: Colors.white, size: 11),
                        ),
                      ),
                    if (isSelected && !isSyncFolder)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
                if (isSyncFolder)
                  const Icon(Icons.lock_outline_rounded,
                      color: Colors.grey, size: 18)
                else if (!isSelectionMode)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 22,
                      icon: const Icon(Icons.more_vert,
                          color: Colors.grey),
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
    ));
  }
}

// ── Folder List Tile ──────────────────────────────────────────────────────────
class _FolderListTile extends StatelessWidget {
  final FolderModel folder;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isSyncFolder;
  final VoidCallback onTap;
  final VoidCallback onSelectTap;
  final VoidCallback onMenuTap;

  const _FolderListTile({
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    this.isSyncFolder = false,
    required this.onTap,
    required this.onSelectTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final folderColor = isSyncFolder ? Colors.blue : Colors.amber;
    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surface,
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
              ? const Border(
              left: BorderSide(color: Colors.blue, width: 3))
              : null,
        ),
        child: ListTile(
          onTap: isSelectionMode
              ? (isSyncFolder ? null : onSelectTap)
              : onTap,
          onLongPress: isSyncFolder ? null : onSelectTap,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: isSelectionMode && !isSyncFolder
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
              color: folderColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_rounded,
                color: folderColor, size: 22),
          ),
          title: Text(
            folder.name,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing: isSyncFolder
              ? const Icon(Icons.lock_outline_rounded,
                  color: Colors.grey, size: 18)
              : isSelectionMode
                  ? null
                  : IconButton(
              icon: const Icon(Icons.more_vert,
                  color: Colors.grey, size: 22),
              onPressed: onMenuTap,
            ),
        ),
      ),
    ));
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

  final VoidCallback? onTap;
  final VoidCallback? onSelectTap;

  const _FileTile({
    super.key,
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onMenuTap,
    this.downloadProgress,
    this.downloadReceivedBytes,
    this.onFavouriteTap,
    this.authToken,
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
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    }
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
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 10),
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
    return RepaintBoundary(child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surface,
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
              ? const Border(
              left: BorderSide(color: Colors.blue, width: 3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: isSelectionMode ? onSelectTap : onTap,
              onLongPress: onSelectTap,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
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
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1A73E8)),
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
                    fontWeight: FontWeight.w500, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _isDownloading
                  ? Text(
                '${DownloadRepository.formatBytes(downloadReceivedBytes ?? 0)} / ${file.formattedSize}',
                style: const TextStyle(
                    color: Color(0xFF1A73E8), fontSize: 12),
              )
                  : Text(
                file.formattedSize,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 13),
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
                    icon: const Icon(Icons.more_vert,
                        color: Colors.grey, size: 22),
                    onPressed: onMenuTap,
                  ),
                ],
              ),
            ),
            if (_isDownloading)
              LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 3,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1A73E8)),
              ),
          ],
        ),
      ),
    ));
  }
}

// ── File Grid Card ────────────────────────────────────────────────────────────
class _FileGridCard extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onSelectTap;
  final VoidCallback onMenuTap;
  final VoidCallback onFavouriteTap;

  const _FileGridCard({
    super.key,
    required this.file,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onSelectTap,
    required this.onMenuTap,
    required this.onFavouriteTap,
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

    return RepaintBoundary(child: GestureDetector(
      onTap: isSelectionMode ? onSelectTap : onTap,
      onLongPress: onSelectTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : null,
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: hasPreview
                        ? CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (_, __) => Container(
                        color: color.withValues(alpha: 0.08),
                        child: Icon(_icon(mime),
                            color: color, size: 40),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: color.withValues(alpha: 0.08),
                        child: Icon(_icon(mime),
                            color: color, size: 40),
                      ),
                    )
                        : Container(
                      color: color.withValues(alpha: 0.08),
                      child: Center(
                        child: Icon(_icon(mime),
                            color: color, size: 40),
                      ),
                    ),
                  ),
                  if (mime.startsWith('video/') && hasPreview)
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                          Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
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
                          border:
                          Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  if (!isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onFavouriteTap,
                        child: Icon(
                          file.isFavourite
                              ? Icons.star
                              : Icons.star_border,
                          color: file.isFavourite
                              ? Colors.amber
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                            color:
                            Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
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
                        icon: const Icon(Icons.more_vert,
                            color: Colors.grey),
                        onPressed: onMenuTap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// ── Info Bottom Sheet ─────────────────────────────────────────────────────────
class _InfoBottomSheet extends StatefulWidget {
  final String id;
  final String type;
  final String name;
  final String previewUrl;
  final Color iconColor;
  final IconData icon;
  final Future<Map<String, dynamic>> Function() fetchInfo;
  final String Function(dynamic) fmt;

  const _InfoBottomSheet({
    required this.id,
    required this.type,
    required this.name,
    required this.previewUrl,
    required this.iconColor,
    required this.icon,
    required this.fetchInfo,
    required this.fmt,
  });

  @override
  State<_InfoBottomSheet> createState() => _InfoBottomSheetState();
}

class _InfoBottomSheetState extends State<_InfoBottomSheet> {
  Map<String, dynamic>? _info;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.fetchInfo();
      if (mounted)
        setState(() {
          _info = data;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return '${dt.day} ${months[dt.month - 1]}. ${dt.year} г., '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final isFolder = widget.type == 'folder';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isFolder ? t.folderDetails : t.fileDetails,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.previewUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: widget.previewUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _iconBox(cs),
                      errorWidget: (_, __, ___) => _iconBox(cs),
                    )
                        : _iconBox(cs),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isFolder && _info != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.fmt(_info!['size']),
                            style: TextStyle(
                              fontSize: 13,
                              color:
                              cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        if (isFolder && !_isLoading) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(_info?['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_info != null)
                isFolder
                    ? _buildFolderInfo(cs, t)
                    : _buildFileInfo(cs, t),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(ColorScheme cs) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: widget.iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(widget.icon, color: widget.iconColor, size: 26),
    );
  }

  Widget _buildFileInfo(ColorScheme cs, AppLocalizations t) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.fileName,
                value: _info!['name'] ?? widget.name,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.fileSize,
                value: widget.fmt(_info!['size']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.createdAt,
                value: _formatDate(_info!['created_at']),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.capturedAt,
                value: _formatDate(_info!['captured_at']),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFolderInfo(ColorScheme cs, AppLocalizations t) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.fileName,
                value: _info!['name'] ?? widget.name,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.totalSize,
                value: widget.fmt(_info!['total_size']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.folderCount,
                value: '${_info!['folder_count'] ?? 0}',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoTile(
                cs: cs,
                label: t.fileCount,
                value: '${_info!['file_count'] ?? 0}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Info Tile ─────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final ColorScheme cs;
  final String label;
  final String value;

  const _InfoTile({
    required this.cs,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
