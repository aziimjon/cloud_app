import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/home_repository.dart';
import '../data/models/folder_model.dart';
import '../data/models/file_model.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/dio_client.dart';
import 'photo_viewer_page.dart';
import 'video_player_page.dart';
import '../../share/data/repository/share_repository_impl.dart';
import '../../share/data/remote/share_remote_data_source_impl.dart';
import '../../share/presentation/bloc/share_bloc.dart';
import '../../share/presentation/bloc/share_event.dart';
import '../../share/presentation/bloc/share_state.dart';

enum _SffFilterType { all, images, videos }


class ShareFolderFilesPage extends StatefulWidget {
  final String userId;
  final String? folderId;
  final String userName;

  const ShareFolderFilesPage({
    super.key,
    required this.userId,
    required this.folderId,
    required this.userName,
  });

  @override
  State<ShareFolderFilesPage> createState() => _ShareFolderFilesPageState();
}

class _ShareFolderFilesPageState extends State<ShareFolderFilesPage> {
  final _repo = HomeRepository();
  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  bool _isLoading = true;
  String? _error;
  bool _isGrid = true;
  String? _authToken;
  final Map<String, String> _previewUrls = {};
  final Set<String> _selectedFiles = {};
  final Set<String> _selectedFolders = {};
  late final ShareBloc _shareBloc;
  final _scrollController = ScrollController();

  String? _currentFolderId;
  final List<({String id, String name})> _breadcrumb = [];

  bool get _isSelectionMode =>
      _selectedFiles.isNotEmpty || _selectedFolders.isNotEmpty;

  _SffFilterType _activeFilter = _SffFilterType.all;

  List<FileModel> get _displayFiles {
    if (_activeFilter == _SffFilterType.all) return _files;
    return _files.where((f) {
      final m = f.mimeType.toLowerCase();
      return _activeFilter == _SffFilterType.images
          ? m.startsWith('image/')
          : m.startsWith('video/');
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentFolderId = widget.folderId;
    _shareBloc = ShareBloc(
      ShareRepositoryImpl(
        ShareRemoteDataSourceImpl(DioClient.instance),
      ),
    );
    _loadAuthToken();
    _loadContent();
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

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> data;
      if (_currentFolderId == null) {
        data = await _repo.getSharedFromUser(widget.userId);
      } else {
        data = await _repo.getSharedFolder(widget.userId, _currentFolderId!);
      }

      // Parse response — handle various API shapes
      List<dynamic> items = [];
      if (data.containsKey('results')) {
        items = (data['results'] ?? []) as List<dynamic>;
      } else if (data.containsKey('files')) {
        items = (data['files'] ?? []) as List<dynamic>;
      } else if (data.containsKey('result')) {
        final result = data['result'];
        if (result is List) {
          items = result;
        } else if (result is Map) {
          items = (result['results'] ?? result['files'] ?? []) as List<dynamic>;
        }
      }

      final folders = <FolderModel>[];
      final files = <FileModel>[];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          if (item['type'] == 'folder') {
            folders.add(FolderModel.fromJson(item));
          } else {
            files.add(FileModel.fromJson(item));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _folders = folders;
        _files = files;
        _isLoading = false;
      });
      _loadPreviewUrls(files);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadPreviewUrls(List<FileModel> files) {
    for (final f in files) {
      if (f.thumbnailPath != null &&
          f.thumbnailPath!.isNotEmpty &&
          !_previewUrls.containsKey(f.id)) {
        _previewUrls[f.id] = f.thumbnailPath!;
      }
    }
  }

  // ── Navigation ──

  void _openFolder(FolderModel folder) {
    setState(() {
      _breadcrumb.add((id: folder.id, name: folder.name));
      _currentFolderId = folder.id;
      _selectedFiles.clear();
      _selectedFolders.clear();
    });
    _loadContent();
  }

  void _goBack() {
    setState(() {
      _breadcrumb.removeLast();
      _currentFolderId =
          _breadcrumb.isEmpty ? widget.folderId : _breadcrumb.last.id;
    });
    _loadContent();
  }

  void _goToRoot() {
    setState(() {
      _breadcrumb.clear();
      _currentFolderId = widget.folderId;
    });
    _loadContent();
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      _breadcrumb.removeRange(index + 1, _breadcrumb.length);
      _currentFolderId = _breadcrumb[index].id;
    });
    _loadContent();
  }

  // ── File viewer ──

  Future<void> _openFileViewer(FileModel file) async {
    final mime = file.mimeType.toLowerCase();
    if (mime.startsWith('image/')) {
      final allImages = _displayFiles
          .where((f) => f.mimeType.toLowerCase().startsWith('image/'))
          .toList();
      final idx = allImages.indexWhere((f) => f.id == file.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoViewerPage(
            files: allImages
                .map((f) => (
                      url: f.id.isNotEmpty ? '' : (f.thumbnailPath ?? ''),
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
            const SnackBar(content: Text('Не удалось открыть видео')),
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

  // ── Selection ──

  void _toggleFileSelection(String id) {
    setState(() {
      if (_selectedFiles.contains(id)) {
        _selectedFiles.remove(id);
      } else {
        _selectedFiles.add(id);
      }
    });
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

  // ── Menus ──

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
                                color: cs.onSurface.withValues(alpha: 0.5),
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
                  icon: Icons.delete_rounded,
                  color: Colors.red,
                  title: 'Удалить',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmDialog(
                      itemName: file.name,
                      onConfirm: () {
                        _shareBloc.add(RevokeShare(
                          fileIds: [file.id],
                          folderIds: const [],
                        ));
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
                      const Icon(
                        Icons.folder_rounded,
                        color: Colors.amber,
                        size: 32,
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
                  icon: Icons.delete_rounded,
                  color: Colors.red,
                  title: 'Удалить',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmDialog(
                      itemName: folder.name,
                      onConfirm: () {
                        _shareBloc.add(RevokeShare(
                          fileIds: const [],
                          folderIds: [folder.id],
                        ));
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog({
    required String itemName,
    required VoidCallback onConfirm,
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  IconData _icon(String mime) {
    final m = mime.toLowerCase();
    if (m.startsWith('image/')) return Icons.image;
    if (m.startsWith('video/')) return Icons.videocam;
    if (m.startsWith('audio/')) return Icons.audiotrack;
    if (m.contains('pdf')) return Icons.picture_as_pdf;
    if (m.contains('word') || m.contains('document')) return Icons.description;
    if (m.contains('excel') || m.contains('sheet')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _color(String mime) {
    final m = mime.toLowerCase();
    if (m.startsWith('image/')) return Colors.pink;
    if (m.startsWith('video/')) return Colors.deepPurple;
    if (m.startsWith('audio/')) return Colors.orange;
    if (m.contains('pdf')) return Colors.red;
    if (m.contains('word') || m.contains('document')) return Colors.blue;
    if (m.contains('excel') || m.contains('sheet')) return Colors.green;
    return Colors.blueGrey;
  }

  Widget _buildBottomSheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      onTap: onTap,
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
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textColor),
          ),
        ],
      ),
    );
  }

  // ── Breadcrumb ──

  Widget _buildBreadcrumb() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Root: user
          GestureDetector(
            onTap: _goToRoot,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _breadcrumb.isEmpty
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: _breadcrumb.isEmpty ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      color: _breadcrumb.isEmpty ? Colors.blue : Colors.grey,
                      fontWeight: _breadcrumb.isEmpty
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Breadcrumb items
          for (int i = 0; i < _breadcrumb.length; i++) ...[
            Icon(Icons.chevron_right, size: 18,
                color: isDark ? Colors.white38 : Colors.grey),
            GestureDetector(
              onTap: i == _breadcrumb.length - 1
                  ? null
                  : () => _navigateToBreadcrumb(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  // ── Bottom action bar ──

  Widget _buildBottomActionBar() {
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
            padding:
                const EdgeInsets.only(left: 8, right: 8, top: 10, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
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
                            _selectedFiles.addAll(_files.map((f) => f.id));
                            _selectedFolders
                                .addAll(_folders.map((f) => f.id));
                          });
                        },
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Все',
                          style: TextStyle(
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
                // Only delete button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionItem(
                      icon: Icons.delete_rounded,
                      label: 'Удалить',
                      iconColor: Colors.red.shade400,
                      textColor: textColor,
                      onTap: () {
                        final fIds = _selectedFiles.toList();
                        final dIds = _selectedFolders.toList();
                        _showDeleteConfirmDialog(
                          itemName:
                              '${fIds.length + dIds.length} элементов',
                          onConfirm: () {
                            _shareBloc.add(RevokeShare(
                              fileIds: fIds,
                              folderIds: dIds,
                            ));
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

  // ── Content list ──

  Widget _buildFileItem(FileModel file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFiles.contains(file.id);
    final previewUrl = _previewUrls[file.id];

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleFileSelection(file.id);
        } else {
          _openFileViewer(file);
        }
      },
      onLongPress: () => _toggleFileSelection(file.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Thumbnail or icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _color(file.mimeType).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: previewUrl != null
                  ? CachedNetworkImage(
                      imageUrl: previewUrl,
                      fit: BoxFit.cover,
                      httpHeaders: _authToken != null
                          ? {'Authorization': 'Bearer $_authToken'}
                          : {},
                      errorWidget: (_, __, ___) => Icon(
                        _icon(file.mimeType),
                        color: _color(file.mimeType),
                        size: 20,
                      ),
                    )
                  : Icon(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.formattedSize,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleFileSelection(file.id),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () => _showFileMenu(file),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(FolderModel folder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFolders.contains(folder.id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleFolderSelection(folder.id);
        } else {
          _openFolder(folder);
        }
      },
      onLongPress: () => _toggleFolderSelection(folder.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_rounded, color: Colors.amber, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (_isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleFolderSelection(folder.id),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () => _showFolderMenu(folder),
              ),
          ],
        ),
      ),
    );
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
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Фильтр',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _buildFilterChip(ctx, 'Все', Icons.apps_rounded, _SffFilterType.all),
                  _buildFilterChip(ctx, 'Фото', Icons.image_rounded, _SffFilterType.images),
                  _buildFilterChip(ctx, 'Видео', Icons.videocam_rounded, _SffFilterType.videos),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(BuildContext ctx, String label, IconData icon, _SffFilterType type) {
    final isActive = _activeFilter == type;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = type);
        Navigator.pop(ctx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A73E8) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Colors.grey[700],
          )),
        ]),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _shareBloc,
      child: BlocListener<ShareBloc, ShareState>(
        listener: (context, state) {
          if (state is ShareSuccess) {
            setState(() {
              _selectedFiles.clear();
              _selectedFolders.clear();
            });
            _loadContent();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Доступ отозван'),
                backgroundColor: Colors.green,
              ),
            );
          }
          if (state is ShareError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: PopScope(
          canPop: _breadcrumb.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _breadcrumb.isNotEmpty) {
              _goBack();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_breadcrumb.isNotEmpty) {
                    _goBack();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Text(
                _breadcrumb.isNotEmpty
                    ? _breadcrumb.last.name
                    : widget.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _activeFilter != _SffFilterType.all
                        ? const Color(0xFF1A73E8)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _showFilterSheet,
                  tooltip: 'Фильтр',
                ),
                IconButton(
                  icon: Icon(_isGrid ? Icons.list : Icons.grid_view),
                  onPressed: () => setState(() => _isGrid = !_isGrid),
                ),
              ],
            ),
            body: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadContent,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildBreadcrumb()),
                      if (_isLoading)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.grey, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadContent,
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_folders.isEmpty && _files.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_off,
                                    color: Colors.grey, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Нет файлов',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 8,
                            bottom: 160,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (_folders.isNotEmpty) ...[
                                _buildSectionHeader(
                                    'Папки',
                                    Icons.folder_rounded,
                                    _folders.length),
                                const SizedBox(height: 8),
                                for (final folder in _folders)
                                  _buildFolderItem(folder),
                                const SizedBox(height: 16),
                              ],
                              if (_displayFiles.isNotEmpty) ...[
                                _buildSectionHeader(
                                    'Файлы',
                                    Icons.insert_drive_file,
                                    _displayFiles.length),
                                const SizedBox(height: 8),
                                for (final file in _displayFiles)
                                  _buildFileItem(file),
                              ],
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
