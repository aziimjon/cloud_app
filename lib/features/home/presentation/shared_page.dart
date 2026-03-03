import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/home_repository.dart';
import '../../../core/errors/app_exception.dart';

/// Shared with me — файлы расшаренные другими пользователями
class SharedPage extends StatefulWidget {
  const SharedPage({super.key});

  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> {
  final _repo = HomeRepository();

  List<_SharedUser> _users = [];
  bool _isLoading = true;
  String? _error;

  // ✅ FIX: userId теперь String (бэкенд возвращает id как String или int)
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedFolderId;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _loadSharedUsers();
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
    setState(() {
      _selectedUserId = userId;
      _selectedUserName = userName;
      _isLoading = true;
      _error = null;
      _selectedFolderId = null;
    });
    try {
      final data = await _repo.getSharedFromUser(userId);
      if (!mounted) return;
      setState(() {
        _items = data['results'] ?? data['files'] ?? [];
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

  Future<void> _openSharedFolder(String folderId) async {
    if (_selectedUserId == null) return;
    setState(() {
      _selectedFolderId = folderId;
      _isLoading = true;
    });
    try {
      final data = await _repo.getSharedFolder(_selectedUserId!, folderId);
      if (!mounted) return;
      setState(() {
        _items = data['results'] ?? data['files'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _selectedUserId != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _goBack,
        )
            : null,
        title: Text(
          _selectedUserName ?? 'Shared with me',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectedUserId == null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _loadSharedUsers,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _selectedUserId == null
          ? _buildUserList()
          : _buildFileList(),
    );
  }

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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                user.fullName.isNotEmpty
                    ? user.fullName[0].toUpperCase()
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
            user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            user.phoneNumber,
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
            Text(
              'Здесь пока пусто',
              style: TextStyle(color: Colors.grey[600]),
            ),
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
      onTap: isFolder ? () => _openSharedFolder(id) : null,
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
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _SharedUser {
  // ✅ FIX: id как String — парсим из любого типа (int или String)
  final String id;
  final String fullName;
  final String phoneNumber;

  const _SharedUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
  });

  factory _SharedUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json;
    return _SharedUser(
      // ✅ FIX: toString() — безопасно работает и с int и со String
      id: user['id']?.toString() ?? '',
      fullName: user['full_name'] ?? '',
      phoneNumber: user['phone_number'] ?? '',
    );
  }
}