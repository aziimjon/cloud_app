import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/login_page.dart';
import '../data/profile_repository.dart';
import 'package:file_picker/file_picker.dart';
import '../../../main.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onLogout;
  const ProfilePage({super.key, this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repo = ProfileRepository();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _storageData;
  Map<String, dynamic>? _usageData;
  bool _isLoading = true;
  String _lang = 'ru';

  // Accent color constant
  static const _accent = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadLang();
  }

  Future<void> _loadLang() async {
    // Language preference — currently defaults to 'ru'
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getMe(),
        _repo.getStorageUsed(),
        _repo.getStorageUsage(),
      ]);
      if (!mounted) return;
      setState(() {
        _userData = results[0];
        _storageData = results[1];
        _usageData = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String get _fullName =>
      _userData?['full_name'] as String? ??
      _userData?['name'] as String? ??
      'Пользователь';

  String get _phone =>
      _userData?['phone_number'] as String? ??
      _userData?['phone'] as String? ??
      '';

  String? get _avatarUrl =>
      _userData?['image'] as String?;

  // ── Bytes formatter ─────────────────────────────────────────────────────────
  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 КБ';
    final b = (bytes is num) ? bytes.toDouble() : double.tryParse(bytes.toString()) ?? 0;
    if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)} ГБ';
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} МБ';
    return '${(b / 1024).toStringAsFixed(0)} КБ';
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    await SecureStorage.clearTokens();
    DioClient.reset();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  // ── Avatar picker ───────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      await _repo.uploadAvatar(file);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аватар обновлён')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Edit name sheet ─────────────────────────────────────────────────────────
  void _showEditNameSheet() {
    final controller = TextEditingController(text: _fullName);
    showModalBottomSheet(
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
              const Text('Изменить имя',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Новое имя',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await _repo.updateProfile(fullName: name);
                      await SecureStorage.saveFullName(name);
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Имя обновлено')),
                        );
                      }
                    } on AppException catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(e.message),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Сохранить',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit phone sheet ────────────────────────────────────────────────────────
  void _showEditPhoneSheet() {
    final controller = TextEditingController(text: _phone);
    showModalBottomSheet(
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
              const Text('Изменить телефон',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Новый номер',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final phone = controller.text.trim();
                    if (phone.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await _repo.updateProfile(phone: phone);
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Телефон обновлён')),
                        );
                      }
                    } on AppException catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(e.message),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Сохранить',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Change password sheet ───────────────────────────────────────────────────
  void _showChangePasswordSheet() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                const Text('Изменить пароль',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: currentCtrl,
                  hint: 'Старый пароль',
                  obscure: obscureCurrent,
                  onToggle: () =>
                      setSheetState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: newCtrl,
                  hint: 'Новый пароль',
                  obscure: obscureNew,
                  onToggle: () =>
                      setSheetState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: confirmCtrl,
                  hint: 'Подтвердить пароль',
                  obscure: obscureConfirm,
                  onToggle: () =>
                      setSheetState(() => obscureConfirm = !obscureConfirm),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (newCtrl.text != confirmCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Пароли не совпадают'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (newCtrl.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Минимум 8 символов'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await _repo.changePassword(
                          current: currentCtrl.text,
                          newPass: newCtrl.text,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Пароль изменён')),
                          );
                        }
                      } on AppException catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Сохранить',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey[400],
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  // ── Language sheet ──────────────────────────────────────────────────────────
  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Выберите язык',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildLangOption('🇷🇺', 'Русский', 'ru', ctx),
              _buildLangOption('🇺🇿', "O'zbekcha", 'uz', ctx),
              _buildLangOption('🇬🇧', 'English', 'en', ctx),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangOption(
      String flag, String label, String code, BuildContext ctx) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Radio<String>(
        value: code,
        groupValue: _lang,
        activeColor: _accent,
        onChanged: (v) {
          setState(() => _lang = v ?? 'ru');
          Navigator.pop(ctx);
        },
      ),
      onTap: () {
        setState(() => _lang = code);
        Navigator.pop(ctx);
      },
    );
  }

  String get _langLabel {
    switch (_lang) {
      case 'uz':
        return "O'zbekcha";
      case 'en':
        return 'English';
      default:
        return 'Русский';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 60),
                      _buildNamePhone(),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildEditSection(),
                            const SizedBox(height: 16),
                            _buildStorage(),
                            const SizedBox(height: 16),
                            _buildLanguage(),
                            const SizedBox(height: 16),
                            _buildTheme(),
                            const SizedBox(height: 24),
                            _buildLogout(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── SECTION 1: Header with gradient + avatar ───────────────────────────────
  Widget _buildHeader() {
    return SizedBox(
      height: 170,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient header
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Avatar
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _avatarUrl != null
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null
                          ? const Icon(Icons.person,
                              size: 48, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Name & phone ───────────────────────────────────────────────────────────
  Widget _buildNamePhone() {
    return Column(
      children: [
        Text(
          _fullName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _phone,
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── SECTION 2: Edit data ──────────────────────────────────────────────────
  Widget _buildEditSection() {
    return _buildSectionCard(
      title: 'ЛИЧНЫЕ ДАННЫЕ',
      child: Column(
        children: [
          _buildSettingsTile(
            Icons.person_outline_rounded,
            'Изменить имя',
            _fullName,
            _showEditNameSheet,
          ),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
          _buildSettingsTile(
            Icons.phone_outlined,
            'Изменить телефон',
            _phone.isNotEmpty ? _phone : 'Не указан',
            _showEditPhoneSheet,
          ),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
          _buildSettingsTile(
            Icons.lock_outline_rounded,
            'Изменить пароль',
            '••••••••',
            _showChangePasswordSheet,
          ),
        ],
      ),
    );
  }

  // ── SECTION 3: Storage ────────────────────────────────────────────────────
  Widget _buildStorage() {
    final percentUsed =
        (_storageData?['percent_used'] as num?)?.toDouble() ?? 0;
    final storageLimit = _storageData?['storage_limit'];
    final usedStorage = _storageData?['used_storage'];
    final images = _usageData?['images'];
    final videos = _usageData?['videos'];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, color: _accent),
              const SizedBox(width: 8),
              const Text('Хранилище',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${_formatBytes(usedStorage)} из ${_formatBytes(storageLimit)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentUsed / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStorageTile(
                  Icons.image, 'Фото', _formatBytes(images), const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _buildStorageTile(
                  Icons.videocam, 'Видео', _formatBytes(videos), const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTile(
      IconData icon, String label, String size, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text(size,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── SECTION 4: Language ───────────────────────────────────────────────────
  Widget _buildLanguage() {
    return _buildSectionCard(
      child: _buildSettingsTile(
        Icons.language_rounded,
        'Язык',
        _langLabel,
        _showLanguageSheet,
      ),
    );
  }

  // ── SECTION 5: Theme ──────────────────────────────────────────────────────
  Widget _buildTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSectionCard(
      title: 'ОФОРМЛЕНИЕ',
      child: Row(
        children: [
          _buildThemeTile('Светлая', Icons.wb_sunny_rounded, false, isDark),
          const SizedBox(width: 8),
          _buildThemeTile('Тёмная', Icons.nightlight_round, true, isDark),
        ],
      ),
    );
  }

  Widget _buildThemeTile(
      String label, IconData icon, bool isDarkOption, bool currentIsDark) {
    final isActive = isDarkOption == currentIsDark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ThemeNotifier.instance.setMode(
            isDarkOption ? ThemeMode.dark : ThemeMode.light,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? _accent.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? _accent : Colors.grey.withValues(alpha: 0.2),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isActive ? _accent : Colors.grey[400], size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? _accent : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SECTION 6: Logout ─────────────────────────────────────────────────────
  Widget _buildLogout() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Выйти из аккаунта',
            style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Выход'),
              content:
                  const Text('Вы уверены, что хотите выйти из аккаунта?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _logout();
                  },
                  child: const Text('Выйти',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REUSABLE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionCard({required Widget child, String? title}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}