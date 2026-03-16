import 'package:flutter/material.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<({String url, String name, String fileId})> files;
  final int initialIndex;
  final String? authToken;
  final Future<String?> Function(String fileId)? onNeedFullUrl;

  const PhotoViewerPage({
    super.key,
    required this.files,
    this.initialIndex = 0,
    this.authToken,
    this.onNeedFullUrl,
  });

  /// Convenience factory for opening a single image (backward compatible).
  factory PhotoViewerPage.single({
    required String imageUrl,
    required String fileName,
    String? authToken,
    String fileId = '',
  }) {
    return PhotoViewerPage(
      files: [(url: imageUrl, name: fileName, fileId: fileId)],
      initialIndex: 0,
      authToken: authToken,
    );
  }

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<String, String> _fullUrls = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadUrlForIndex(widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUrlForIndex(int index) async {
    if (index < 0 || index >= widget.files.length) return;
    final item = widget.files[index];
    if (item.fileId.isEmpty) return; // no fileId — use url as-is
    if (_fullUrls.containsKey(item.fileId)) return;
    if (_loading.contains(item.fileId)) return;

    setState(() => _loading.add(item.fileId));

    final fullUrl =
        await widget.onNeedFullUrl?.call(item.fileId) ?? item.url;

    if (mounted) {
      setState(() {
        _fullUrls[item.fileId] = fullUrl;
        _loading.remove(item.fileId);
      });
    }

    // Preload next
    if (index + 1 < widget.files.length) {
      _loadUrlForIndex(index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = widget.files[_currentIndex];
    final titleText = widget.files.length > 1
        ? '${currentFile.name}  (${_currentIndex + 1}/${widget.files.length})'
        : currentFile.name;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          titleText,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          _loadUrlForIndex(index);
        },
        itemBuilder: (ctx, index) {
          final item = widget.files[index];
          final url = _fullUrls[item.fileId] ?? item.url;
          final isLoading =
              _loading.contains(item.fileId) && item.url.isEmpty;

          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (url.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final Map<String, String> headers = {};
          if (widget.authToken != null) {
            headers['Authorization'] = 'Bearer ${widget.authToken}';
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                url,
                headers: headers,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 64),
                    SizedBox(height: 12),
                    Text(
                      'Не удалось загрузить изображение',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
