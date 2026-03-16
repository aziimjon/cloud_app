import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/home_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/dio_client.dart';
import 'photo_viewer_page.dart';
import 'video_player_page.dart';
import '../../share/data/models/share_models.dart';
import '../../share/presentation/bloc/share_bloc.dart';
import '../../share/presentation/bloc/share_event.dart';
import '../../share/presentation/bloc/share_state.dart';
import '../../share/presentation/pages/share_user_files_page.dart';
import '../../share/presentation/widgets/share_dialog.dart';
import '../../share/data/repository/share_repository_impl.dart';
import '../../share/data/remote/share_remote_data_source_impl.dart';
import 'share_folder_files_page.dart';

/// Shared page — combines "Shared with me" and "Shared by me" via segments.
class SharedPage extends StatefulWidget {
  const SharedPage({super.key});

  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> {
  final _repo = HomeRepository();

  // ── "Shared with me" state (existing, untouched) ────────────────────────────
  List<_SharedUser> _users = [];
  bool _isLoading = true;
  String? _error;
  String? _authToken;
  final Map<String, String> _previewUrls = {};

  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedFolderId;
  List<dynamic> _items = [];

  // ── Segment control state ───────────────────────────────────────────────────
  int _activeSegment = 0; // 0 = Shared with me, 1 = Shared by me
  int _activeByMeTab = 0; // 0 = Users, 1 = Shared items

  // ── ShareBloc for "Shared by me" ────────────────────────────────────────────
  late final ShareBloc _shareBloc;

  @override
  void initState() {
    super.initState();
    _loadSharedUsers();
    _loadAuthToken();
    _shareBloc = ShareBloc(
      ShareRepositoryImpl(
        ShareRemoteDataSourceImpl(DioClient.instance),
      ),
    );
  }

  @override
  void dispose() {
    _shareBloc.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  EXISTING "Shared with me" methods — NOT CHANGED
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _loadAuthToken() async {
    final token = await SecureStorage.getAccessToken();
    if (mounted) setState(() => _authToken = token);
  }

  void _loadPreviewUrls(List<dynamic> items) {
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      final rawMime = item['mime_type'];
      if (id.isEmpty || rawMime == null) continue;
      String mimeType = '';
      try {
        mimeType = utf8.decode(base64.decode(rawMime.toString()));
      } catch (_) {
        mimeType = rawMime.toString();
      }

      final mime = mimeType.toLowerCase();
      final thumbPath = item['thumbnail_path']?.toString();
      if (mime.startsWith('image/') &&
          thumbPath != null &&
          !_previewUrls.containsKey(id)) {
        _previewUrls[id] = thumbPath;
      }
    }
    if (mounted) setState(() {});
  }

  void _openFileViewer(Map<String, dynamic> item, String name) {
    final id = item['id']?.toString() ?? '';

    String mimeType = '';
    final rawMime = item['mime_type'];
    if (rawMime != null) {
      try {
        mimeType = utf8.decode(base64.decode(rawMime.toString()));
      } catch (_) {
        mimeType = rawMime.toString();
      }
    }

    final mime = mimeType.toLowerCase();
    if (mime.startsWith('image/')) {
      _openImageViewer(id, name);
    } else if (mime.startsWith('video/')) {
      _openVideoViewer(id, name);
    }
  }

  Future<void> _openImageViewer(String fileId, String name) async {
    final url = await _repo.getPreviewUrl(fileId);
    if (url == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть изображение')),
        );
      return;
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoViewerPage.single(imageUrl: url, fileName: name),
        ),
      );
    }
  }

  Future<void> _openVideoViewer(String fileId, String name) async {
    final url = await _repo.getPreviewUrl(fileId);
    if (url == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть видео')),
        );
      return;
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(videoUrl: url, fileName: name),
        ),
      );
    }
  }

  Future<void> _loadSharedUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _repo.getSharedWithMe();
      if (!mounted) return;
      setState(() {
        _users = results
            .map((e) => _SharedUser.fromJson(e as Map<String, dynamic>))
            .toList();
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

  Future<void> _openUserFiles(String userId, String userName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareFolderFilesPage(
          userId: userId,
          folderId: null,
          userName: userName,
        ),
      ),
    );
    _loadSharedUsers();
  }

  Future<void> _openSharedFolder(String folderId) async {
    if (_selectedUserId == null) return;
    setState(() {
      _selectedFolderId = folderId;
      _isLoading = true;
    });
    try {
      final data = await _repo.getSharedFolder(_selectedUserId!, folderId);
      if (!mounted) return;
      // Swagger: ControllerDefaultResponse { message, result }
      final result = data['result'];
      List<dynamic> items = [];
      if (result is List) {
        items = result;
      } else if (result is Map) {
        items = result['results'] ?? result['files'] ?? [];
      } else {
        items = data['results'] ?? data['files'] ?? [];
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
      _loadPreviewUrls(_items);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    if (_selectedFolderId != null) {
      _openUserFiles(_selectedUserId!, _selectedUserName!);
    } else {
      setState(() {
        _selectedUserId = null;
        _selectedUserName = null;
        _items = [];
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  Segment switching
  // ══════════════════════════════════════════════════════════════════════════════

  void _switchSegment(int segment) {
    if (_activeSegment == segment) return;
    setState(() {
      _activeSegment = segment;
      if (segment == 1) {
        // Reset "with me" detail view
        _selectedUserId = null;
        _selectedUserName = null;
        _selectedFolderId = null;
        _items = [];
      }
    });
    if (segment == 1) {
      if (_activeByMeTab == 0) {
        _shareBloc.add(const LoadSharedByMeUsers());
      } else {
        _shareBloc.add(const LoadSharedByMe());
      }
    }
  }

  void _switchByMeTab(int tab) {
    if (_activeByMeTab == tab) return;
    setState(() => _activeByMeTab = tab);
    if (tab == 0) {
      _shareBloc.add(const LoadSharedByMeUsers());
    } else {
      _shareBloc.add(const LoadSharedByMe());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool inDetail = _selectedUserId != null;

    return BlocProvider.value(
      value: _shareBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: inDetail
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: _goBack,
                )
              : null,
          title: Text(
            inDetail ? (_selectedUserName ?? 'Shared') : 'Shared',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (!inDetail && _activeSegment == 0)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black),
                onPressed: _loadSharedUsers,
              ),
          ],
        ),
        body: Column(
          children: [
            if (!inDetail) _buildSegmentControl(),
            Expanded(
              child: inDetail
                  ? (_isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _buildError()
                          : _buildFileList())
                  : _activeSegment == 0
                      ? _buildWithMeBody()
                      : _buildByMeBody(),
            ),
          ],
        ),
        floatingActionButton:
            (!inDetail && _activeSegment == 1 && _activeByMeTab == 0)
                ? FloatingActionButton(
                    backgroundColor: const Color(0xFF1A73E8),
                    child: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: _shareBloc,
                        child: const ShareDialog(),
                      ),
                    ),
                  )
                : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  SEGMENT CONTROL
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildSegmentControl() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _segmentButton('Shared with me', 0),
            const SizedBox(width: 4),
            _segmentButton('Shared by me', 1),
          ],
        ),
      ),
    );
  }

  Widget _segmentButton(String label, int index) {
    final active = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchSegment(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A73E8) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF1A73E8),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  "SHARED WITH ME" body (uses existing widgets)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildWithMeBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return _buildUserList();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  "SHARED BY ME" body
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildByMeBody() {
    return Column(
      children: [
        _buildByMeSubTabs(),
        Expanded(
          child: BlocBuilder<ShareBloc, ShareState>(
            builder: (context, state) {
              if (state is ShareLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is ShareError) {
                return _buildByMeError(state.message);
              }
              if (_activeByMeTab == 0 && state is SharedByMeUsersLoaded) {
                return _buildByMeUsers(state.users);
              }
              if (_activeByMeTab == 1 && state is SharedByMeLoaded) {
                return _buildByMeItems(state.shares);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildByMeSubTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _subTabButton('Users', 0),
            const SizedBox(width: 3),
            _subTabButton('Shared items', 1),
          ],
        ),
      ),
    );
  }

  Widget _subTabButton(String label, int index) {
    final active = _activeByMeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchByMeTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A73E8) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF1A73E8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildByMeError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_activeByMeTab == 0) {
                _shareBloc.add(const LoadSharedByMeUsers());
              } else {
                _shareBloc.add(const LoadSharedByMe());
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── "By me → Users" ────────────────────────────────────────────────────────

  Widget _buildByMeUsers(List<SharedByMeUserModel> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.people_rounded,
                size: 40,
                color: Color(0xFF1A73E8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Вы ещё ни с кем не делились',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите кнопку шаринга чтобы поделиться файлами',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          _shareBloc.add(const LoadSharedByMeUsers()),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildByMeUserCard(users[i]),
      ),
    );
  }

  Widget _buildByMeUserCard(SharedByMeUserModel user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShareUserFilesPage(
              userId: user.sharedWith.id,
              userName: user.sharedWith.fullName,
              isSharedByMe: true,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user.sharedWith.fullName.isNotEmpty
                    ? user.sharedWith.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          title: Text(
            user.sharedWith.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${user.sharedWith.phoneNumber} · ${user.sharedCount} файлов',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Открыть',
              style: TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── "By me → Shared items" ─────────────────────────────────────────────────

  Widget _buildByMeItems(List<FileShareModel> shares) {
    if (shares.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_shared_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Нет расшаренных элементов',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _shareBloc.add(const LoadSharedByMe()),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: shares.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildByMeItemCard(shares[i]),
      ),
    );
  }

  Widget _buildByMeItemCard(FileShareModel share) {
    final bool isFolder = share.folder != null;
    final String name = isFolder
        ? (share.folder?.name ?? 'Папка')
        : (share.file?.name ?? 'Файл');

    // Try base64 decode
    String displayName = name;
    try {
      displayName = utf8.decode(base64.decode(name));
    } catch (_) {
      displayName = name;
    }

    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Отозвать доступ'),
            content: Text('Отозвать доступ к «$displayName»?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final fileIds = share.file != null
                      ? [share.file!.id]
                      : <String>[];
                  final folderIds = share.folder != null
                      ? [share.folder!.id]
                      : <String>[];
                  _shareBloc.add(RevokeShare(
                    fileIds: fileIds,
                    folderIds: folderIds,
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Отозвать',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isFolder
                  ? Colors.amber.withValues(alpha: 0.15)
                  : const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFolder
                  ? Icons.folder_rounded
                  : Icons.insert_drive_file_rounded,
              color: isFolder ? Colors.amber : const Color(0xFF1A73E8),
              size: 22,
            ),
          ),
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Для ${share.sharedWith.fullName}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  EXISTING UI widgets — NOT CHANGED
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _selectedUserId == null
                ? _loadSharedUsers
                : () => _openUserFiles(_selectedUserId!, _selectedUserName!),
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.people_rounded,
                size: 40,
                color: Color(0xFF1A73E8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Никто не делился файлами',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Когда кто-то поделится файлом — они появятся здесь',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSharedUsers,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildUserCard(_users[i]),
      ),
    );
  }

  Widget _buildUserCard(_SharedUser user) {
    return GestureDetector(
      onTap: () => _openUserFiles(user.id, user.fullName),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          title: Text(
            user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${user.phoneNumber} · ${user.sharedCount} файлов',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Открыть',
              style: TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Здесь пока пусто', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _items[i] as Map<String, dynamic>;
        final isFolder = item['type'] == 'folder';
        return _buildItemCard(item, isFolder);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isFolder) {
    final rawName = item['name'] ?? '';
    // Декодируем base64 имя если нужно
    String name = rawName;
    try {
      final decoded = utf8.decode(base64.decode(rawName));
      name = decoded;
    } catch (_) {
      name = rawName;
    }
    final id = item['id']?.toString() ?? '';

    return GestureDetector(
      onTap: isFolder
          ? () => _openSharedFolder(id)
          : () => _openFileViewer(item, name),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: _buildItemLeading(item, isFolder, id),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isFolder
              ? const Icon(Icons.chevron_right, color: Colors.grey)
              : null,
        ),
      ),
    );
  }

  Widget _buildItemLeading(
    Map<String, dynamic> item,
    bool isFolder,
    String id,
  ) {
    if (isFolder) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.folder_rounded, color: Colors.amber, size: 22),
      );
    }
    // Decode mime_type if present
    String mimeType = '';
    final rawMime = item['mime_type'];
    if (rawMime != null) {
      try {
        mimeType = utf8.decode(base64.decode(rawMime.toString()));
      } catch (_) {
        mimeType = rawMime.toString();
      }
    }
    final mime = mimeType.toLowerCase();
    final previewUrl = _previewUrls[id];
    if (mime.startsWith('image/') && previewUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: previewUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.image_rounded,
              color: Color(0xFF1A73E8),
              size: 22,
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.image_rounded,
              color: Color(0xFF1A73E8),
              size: 22,
            ),
          ),
        ),
      );
    }
    if (mime.startsWith('video/')) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEA4335).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.videocam_rounded,
              color: Color(0xFFEA4335),
              size: 22,
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFFEA4335),
                  shape: BoxShape.circle,
                ),
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.insert_drive_file_rounded,
        color: Color(0xFF1A73E8),
        size: 22,
      ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _SharedUser {
  final String id;
  final String fullName;
  final String phoneNumber;
  final int sharedCount;

  const _SharedUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.sharedCount,
  });

  factory _SharedUser.fromJson(Map<String, dynamic> json) {
    // Swagger: SharedWithMeUser { owner: User, shared_count: int }
    final user = json['owner'] ?? json;
    return _SharedUser(
      id: user['id']?.toString() ?? '',
      fullName: user['full_name'] ?? '',
      phoneNumber: user['phone_number'] ?? '',
      sharedCount: json['shared_count'] as int? ?? 0,
    );
  }
}
