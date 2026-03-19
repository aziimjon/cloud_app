import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_app/l10n/app_localizations.dart';
import '../../../core/storage/secure_storage.dart';
import '../../profile/data/profile_repository.dart';
import '../../../main.dart';

class HomePage extends StatefulWidget {
  final void Function(String? folderId)? onFolderChanged;
  final VoidCallback? onNavigateToFiles;
  final VoidCallback? onNavigateToShared;
  final VoidCallback? onToggleFavourites;

  const HomePage({
    super.key,
    this.onFolderChanged,
    this.onNavigateToFiles,
    this.onNavigateToShared,
    this.onToggleFavourites,
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _profileRepo = ProfileRepository();
  Map<String, dynamic> _storageData = {};
  Map<String, dynamic> _statsData = {};
  String? _userName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final name = await SecureStorage.getFullName();
    try {
      final results = await Future.wait([
        _profileRepo.getStorageUsed(),
        _profileRepo.getContentStatistics(),
      ]);
      if (mounted) {
        setState(() {
          _userName = name;
          _storageData = results[0];
          _statsData = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _userName = name; _isLoading = false; });
    }
  }

  void reloadContent() => _loadData();

  String _fmt(dynamic b) {
    if (b == null) return '0 KB';
    final v = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
    if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(2)} GB';
    if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(1)} MB';
    return '${(v / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: cs.surface,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.welcomeBack,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userName ?? t.profile,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  background: Container(color: cs.surface),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      color: cs.onSurface,
                    ),
                    onPressed: () => ThemeNotifier.instance.toggle(),
                    tooltip: t.theme,
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: cs.onSurface),
                    onPressed: _loadData,
                    tooltip: t.refresh,
                  ),
                  const SizedBox(width: 4),
                ],
              ),

              SliverToBoxAdapter(
                child: _isLoading
                    ? const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStorageCard(cs, t),
                      const SizedBox(height: 24),
                      _buildStatisticsSection(cs, t),
                      const SizedBox(height: 24),
                      _buildQuickActions(context, t),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageCard(ColorScheme cs, AppLocalizations t) {
    final used = _storageData['used_storage'];
    final limit = _storageData['storage_limit'];
    final percent = (_storageData['percent_used'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF4A90E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.myCloudStorage,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    t.yourCloudStorage,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_fmt(used)} ${t.used}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_fmt(limit)} ${t.total}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(ColorScheme cs, AppLocalizations t) {
    final image = _statsData['image'] as Map<String, dynamic>? ?? {};
    final video = _statsData['video'] as Map<String, dynamic>? ?? {};
    final sharedByMe = _statsData['shared_by_me'] as Map<String, dynamic>? ?? {};
    final sharedWithMe = _statsData['shared_with_me'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.overallStats,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.image_rounded,
                iconColor: const Color(0xFF1A73E8),
                label: t.images,
                count: '${image['count'] ?? 0}',
                subtitle: _fmt(image['size']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.videocam_rounded,
                iconColor: const Color(0xFFE53935),
                label: t.videos,
                count: '${video['count'] ?? 0}',
                subtitle: _fmt(video['size']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.share_rounded,
                iconColor: Colors.green,
                label: t.sharedByMe,
                count: '${(sharedByMe['files'] ?? 0) + (sharedByMe['folders'] ?? 0)}',
                subtitle: '${sharedByMe['users'] ?? 0} ${t.participants} · ${sharedByMe['folders'] ?? 0} ${t.folders.toLowerCase()}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.person_rounded,
                iconColor: Colors.orange,
                label: t.sharedWithMe,
                count: '${(sharedWithMe['files'] ?? 0) + (sharedWithMe['folders'] ?? 0)}',
                subtitle: '${sharedWithMe['users'] ?? 0} ${t.participants} · ${sharedWithMe['folders'] ?? 0} ${t.folders.toLowerCase()}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.quickActions,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.folder_rounded,
                label: t.myFiles,
                color: const Color(0xFF1A73E8),
                onTap: () => widget.onNavigateToFiles?.call(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.star_rounded,
                label: t.favourites,
                color: Colors.amber,
                onTap: () => widget.onToggleFavourites?.call(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.people_rounded,
                label: t.shared,
                color: Colors.green,
                onTap: () => widget.onNavigateToShared?.call(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String count;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Card ───────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
