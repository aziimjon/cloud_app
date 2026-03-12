import 'package:flutter/material.dart';
import 'package:cloud_app/features/home/data/home_repository.dart';
import 'package:cloud_app/features/home/data/models/folder_model.dart';
import 'package:cloud_app/core/errors/app_exception.dart';

class MoveDestinationScreen extends StatefulWidget {
  final List<String> selectedFiles;
  final List<String> selectedFolders;
  final String? currentFolderId;

  const MoveDestinationScreen({
    super.key,
    required this.selectedFiles,
    required this.selectedFolders,
    this.currentFolderId,
  });

  @override
  State<MoveDestinationScreen> createState() => _MoveDestinationScreenState();
}

class _MoveDestinationScreenState extends State<MoveDestinationScreen> {
  final _repo = HomeRepository();
  bool _isLoading = true;
  String? _error;
  List<FolderModel> _folders = [];

  // Custom Breadcrumb representation: id and name
  final List<({String id, String name})> _breadcrumb = [];

  String? get _currentFolderId =>
      _breadcrumb.isEmpty ? null : _breadcrumb.last.id;

  @override
  void initState() {
    super.initState();
    _loadCurrentFolder();
  }

  Future<void> _loadCurrentFolder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _repo.getContent(parentId: _currentFolderId);
      final rawFolders = response['folders'] as List;

      if (!mounted) return;

      setState(() {
        if (rawFolders.isNotEmpty && rawFolders.first is FolderModel) {
          _folders = rawFolders.cast<FolderModel>();
        } else {
          _folders = rawFolders
              .map((e) => FolderModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AppException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToFolder(FolderModel folder) {
    if (widget.selectedFolders.contains(folder.id)) {
      return; // disabled
    }

    setState(() {
      _breadcrumb.add((id: folder.id, name: folder.name));
    });
    _loadCurrentFolder();
  }

  void _navigateUp(int index) {
    if (index < 0) {
      setState(() {
        _breadcrumb.clear();
      });
    } else {
      setState(() {
        _breadcrumb.removeRange(index + 1, _breadcrumb.length);
      });
    }
    _loadCurrentFolder();
  }

  Future<void> _confirmMove() async {
    if (_currentFolderId == widget.currentFolderId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файлы уже находятся в этой папке')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _repo.moveItems(
        targetFolderId: _currentFolderId,
        files: widget.selectedFiles,
        folders: widget.selectedFolders,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Выберите папку',
            style: TextStyle(color: Colors.black87, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () => Navigator.pop(context, false),
          ),
          actions: [
            if (!_isLoading && _error == null)
              IconButton(
                icon: const Icon(Icons.check, color: Colors.blue),
                onPressed: _confirmMove,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildBreadcrumbs(),
            const Divider(height: 1, thickness: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _breadcrumb.length + 1,
        separatorBuilder: (_, __) =>
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _BreadcrumbItem(
              title: 'Главная',
              isLast: _breadcrumb.isEmpty,
              onTap: () => _navigateUp(-1),
            );
          }
          final item = _breadcrumb[index - 1];
          return _BreadcrumbItem(
            title: item.name,
            isLast: index == _breadcrumb.length,
            onTap: () => _navigateUp(index - 1),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCurrentFolder,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Папка пуста', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final isDisabled = widget.selectedFolders.contains(folder.id);

        return ListTile(
          enabled: !isDisabled,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDisabled
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.folder_rounded,
              color: isDisabled ? Colors.grey : Colors.amber,
              size: 22,
            ),
          ),
          title: Text(
            folder.name,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDisabled ? Colors.grey : Colors.black87,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => _navigateToFolder(folder),
        );
      },
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String title;
  final bool isLast;
  final VoidCallback onTap;

  const _BreadcrumbItem({
    required this.title,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLast ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
              color: isLast ? Colors.black87 : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}
