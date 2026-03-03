import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ─── данные пользователя ───────────────────────────────────────────────────
  String _fullName = 'Alex Johnson';
  String _phone = '+1 (555) 123-4567';
  String _plan = 'Pro Plan';

  // ─── хранилище ────────────────────────────────────────────────────────────
  double _usedPercent = 75;
  double _photosGb = 45;
  double _docsGb = 20;
  double _videosGb = 15;
  double _totalGb = 100;

  // ─── настройки ────────────────────────────────────────────────────────────
  String _language = 'English (US)';
  bool _darkMode = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final dio = DioClient.instance;
      final resp = await dio.get('/auth/profile/');
      final data = resp.data is Map ? resp.data : {};
      if (!mounted) return;
      setState(() {
        _fullName = data['full_name'] ?? data['name'] ?? _fullName;
        _phone = data['phone_number'] ?? data['phone'] ?? _phone;
        _plan = data['plan'] ?? data['subscription'] ?? _plan;
        // storage
        final storage = data['storage'];
        if (storage is Map) {
          _usedPercent = (storage['used_percent'] ?? _usedPercent).toDouble();
          _photosGb = (storage['photos_gb'] ?? _photosGb).toDouble();
          _docsGb = (storage['docs_gb'] ?? _docsGb).toDouble();
          _videosGb = (storage['videos_gb'] ?? _videosGb).toDouble();
          _totalGb = (storage['total_gb'] ?? _totalGb).toDouble();
        }
      });
    } catch (_) {
      // используем дефолтные значения
    }
  }

  Future<void> _logout() async {
    await SecureStorage.clearTokens();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F3F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF2F3F7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFF1A73E8), size: 22),
              onPressed: _openEdit,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Аватар ──────────────────────────────────────────────────────
              _buildAvatar(),

              const SizedBox(height: 14),

              // ── Имя ──────────────────────────────────────────────────────────
              Text(
                _fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                _phone,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 10),

              // ── Plan badge ───────────────────────────────────────────────────
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _plan,
                  style: const TextStyle(
                    color: Color(0xFF1A73E8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Storage card ──────────────────────────────────────────────────
              _buildStorageCard(),

              const SizedBox(height: 28),

              // ── PREFERENCES label ─────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PREFERENCES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Language ──────────────────────────────────────────────────────
              _PreferenceItem(
                icon: Icons.language_rounded,
                iconColor: const Color(0xFF1A73E8),
                iconBg: const Color(0xFFE8F0FE),
                title: 'Language',
                subtitle: _language,
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
                onTap: _openLanguage,
              ),

              const SizedBox(height: 10),

              // ── Dark Mode ─────────────────────────────────────────────────────
              _PreferenceItem(
                icon: Icons.dark_mode_rounded,
                iconColor: const Color(0xFF7B7FC4),
                iconBg: const Color(0xFFEEEFF8),
                title: 'Dark Mode',
                subtitle: 'Adjust appearance',
                trailing: Switch(
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
                  activeColor: const Color(0xFF1A73E8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onTap: () => setState(() => _darkMode = !_darkMode),
              ),

              const SizedBox(height: 10),

              // ── Notifications ─────────────────────────────────────────────────
              _PreferenceItem(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFF1A73E8),
                iconBg: const Color(0xFFE8F0FE),
                title: 'Notifications',
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
                onTap: () {},
              ),

              const SizedBox(height: 10),

              // ── Log Out ───────────────────────────────────────────────────────
              _PreferenceItem(
                icon: Icons.logout_rounded,
                iconColor: Colors.red,
                iconBg: const Color(0xFFFFEEEE),
                title: 'Log Out',
                titleColor: Colors.red,
                onTap: _confirmLogout,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Аватар с кнопкой камеры ─────────────────────────────────────────────────
  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
            image: const DecorationImage(
              // placeholder — в реальном проекте заменить на NetworkImage(avatarUrl)
              image: AssetImage('assets/images/avatar_placeholder.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: ClipOval(
            child: Container(
              color: const Color(0xFFB0BEC5),
              child: const Icon(Icons.person, size: 56, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ── Storage card ─────────────────────────────────────────────────────────────
  Widget _buildStorageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Storage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    color: Color(0xFF1A73E8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Круговой индикатор
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _usedPercent / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1A73E8)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_usedPercent.toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          'USED',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Легенда
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StorageLegendRow(
                      color: const Color(0xFF1A73E8),
                      label: 'Photos',
                      value: '${_photosGb.toInt()} GB',
                      opacity: 1.0,
                    ),
                    const SizedBox(height: 10),
                    _StorageLegendRow(
                      color: const Color(0xFF1A73E8),
                      label: 'Docs',
                      value: '${_docsGb.toInt()} GB',
                      opacity: 0.65,
                    ),
                    const SizedBox(height: 10),
                    _StorageLegendRow(
                      color: const Color(0xFF1A73E8),
                      label: 'Videos',
                      value: '${_videosGb.toInt()} GB',
                      opacity: 0.3,
                    ),
                    const Divider(height: 20, color: Colors.grey),
                    Text(
                      'Total ${_totalGb.toInt()} GB available',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickAvatar() {
    // TODO: image_picker
  }

  void _openEdit() {
    // TODO: edit profile bottom sheet
  }

  void _openLanguage() {
    // TODO: language picker
  }
}

// ─── Preference row ────────────────────────────────────────────────────────────

class _PreferenceItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _PreferenceItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? Colors.black,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ─── Storage legend row ────────────────────────────────────────────────────────

class _StorageLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final double opacity;

  const _StorageLegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(opacity),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}