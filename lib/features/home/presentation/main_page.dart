import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'shared_page.dart';
import '../../upload/presentation/upload_page.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/presentation/login_page.dart';
import '../data/home_repository.dart';
import '../data/models/file_model.dart';
import '../../../core/errors/app_exception.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'photo_viewer_page.dart';
import 'video_player_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  String? _currentFolderId;

  void _onFolderChanged(String? folderId) {
    setState(() {
      _currentFolderId = folderId;
    });
  }

  final _homeKey = GlobalKey<HomePageState>();
  final _recentKey = GlobalKey<_RecentPageState>();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomePage(key: _homeKey, onFolderChanged: _onFolderChanged),
            // ✅ FIX: передаём key чтобы управлять refresh
            _RecentPage(key: _recentKey),
            UploadPage(
              parentId: _currentFolderId,
              onUploadComplete: () {
                // После загрузки — обновляем и Files и Recent
                _homeKey.currentState?.reloadContent();
                _recentKey.currentState?.reload();
                setState(() => _currentIndex = 0);
              },
            ),
            const SharedPage(),
            _ProfilePage(onLogout: _logout),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Future<void> _logout() async {
    await SecureStorage.clearTokens();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.folder_rounded,
                label: 'Files',
                index: 0,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                icon: Icons.access_time_rounded,
                label: 'Recent',
                index: 1,
                current: _currentIndex,
                onTap: (i) {
                  // ✅ FIX: при переходе на Recent — автообновляем список
                  if (i == 1) {
                    _recentKey.currentState?.reload();
                  }
                  setState(() => _currentIndex = i);
                },
              ),
              _UploadButton(
                isActive: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.people_rounded,
                label: 'Shared',
                index: 3,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                current: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav widgets ───────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF1A73E8).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: active ? const Color(0xFF1A73E8) : Colors.grey[400],
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? const Color(0xFF1A73E8) : Colors.grey[400],
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _UploadButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Recent Page ───────────────────────────────────────────────────────────────

class _RecentPage extends StatefulWidget {
  const _RecentPage({super.key});

  @override
  State<_RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<_RecentPage> {
  final _repo = HomeRepository();
  List<FileModel> _files = [];
  bool _isLoading = true;
  String? _error;
  String? _authToken;
  final Map<String, String> _previewUrls = {};

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final token = await SecureStorage.getAccessToken();
    if (mounted) setState(() => _authToken = token);
  }

  void _loadPreviewUrls(List<FileModel> files) {
    for (final f in files) {
      final mime = f.mimeType.toLowerCase();
      if (mime.startsWith('image/') &&
          f.thumbnailPath != null &&
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

  /// ✅ Публичный метод — вызывается из MainPage при переключении на вкладку
  void reload() => _loadRecentFiles();

  Future<void> _loadRecentFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _repo.getRecentFiles();
      if (!mounted) return;
      setState(() {
        _files = results
            .map((e) => FileModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
      _loadPreviewUrls(_files);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  // ✅ FIX: иконка и цвет по mime type — как на HomePage
  IconData _icon(String mime) {
    if (mime.startsWith('image/')) return Icons.image_rounded;
    if (mime.startsWith('video/')) return Icons.videocam_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _color(String mime) {
    if (mime.startsWith('image/')) return const Color(0xFF34A853); // зелёный
    if (mime.startsWith('video/')) return const Color(0xFFEA4335); // красный
    return const Color(0xFF1A73E8); // синий
  }

  Widget _buildFileLeading(FileModel file, Color color) {
    final mime = file.mimeType.toLowerCase();
    final previewUrl = _previewUrls[file.id];
    if (mime.startsWith('image/') && previewUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: previewUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (_, __) => _iconBox(file, color),
          errorWidget: (_, __, ___) => _iconBox(file, color),
        ),
      );
    }
    if (mime.startsWith('video/')) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.videocam_rounded, color: color, size: 22),
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
    return _iconBox(file, color);
  }

  Widget _iconBox(FileModel file, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_icon(file.mimeType), color: color, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Recent',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadRecentFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _loadRecentFiles,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _files.isEmpty
          ? Center(
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
                      Icons.access_time_rounded,
                      size: 40,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Files you open will appear here',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecentFiles,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _files.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final color = _color(file.mimeType);
                  return Container(
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
                      onTap: () => _openFileViewer(file),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: _buildFileLeading(file, color),
                      title: Text(
                        file.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          // ✅ FIX: метка типа файла
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.mimeType.startsWith('image/')
                                  ? 'Фото'
                                  : file.mimeType.startsWith('video/')
                                  ? 'Видео'
                                  : 'Файл',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            file.formattedSize,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: file.isFavourite
                          ? const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Profile Page ──────────────────────────────────────────────────────────────

class _ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;
  const _ProfilePage({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'My Cloud User',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
