import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auto_sync_service.dart';

class AutoSyncSettingsPage extends StatefulWidget {
  const AutoSyncSettingsPage({super.key});

  @override
  State<AutoSyncSettingsPage> createState() => _AutoSyncSettingsPageState();
}

class _AutoSyncSettingsPageState extends State<AutoSyncSettingsPage> {
  static const _accent = Color(0xFF2563EB);

  final AutoSyncService _syncService = AutoSyncService();
  bool _autoSyncEnabled = false;
  bool _wifiOnly = false;
  bool _isSyncing = false;
  StreamSubscription<SyncProgress>? _progressSub;
  SyncProgress _lastProgress = const SyncProgress();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _progressSub = _syncService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _lastProgress = progress;
          _isSyncing = _syncService.isRunning;
        });
      }
    });
    _isSyncing = _syncService.isRunning;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
        _wifiOnly = prefs.getBool('auto_sync_wifi_only') ?? false;
      });
    }
  }

  Future<void> _setAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', value);
    if (mounted) setState(() => _autoSyncEnabled = value);
  }

  Future<void> _setWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_wifi_only', value);
    if (mounted) setState(() => _wifiOnly = value);
  }

  Future<void> _startSync() async {
    setState(() => _isSyncing = true);
    _syncService.startSync();
  }

  Future<void> _stopSync() async {
    await _syncService.stopSync();
    if (mounted) setState(() => _isSyncing = false);
  }

  Future<void> _resetQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Сбросить очередь?'),
        content: const Text(
            'Все записи будут удалены. После этого приложение заново просканирует галерею.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _syncService.onLogout();
      await _syncService.initialize();
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Авто-синхронизация'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Toggle switches
            _buildCard(
              cardColor: cardColor,
              child: Column(
                children: [
                  SwitchListTile(
                    activeTrackColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Включить авто-синхронизацию',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Автоматически загружать фото и видео',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _autoSyncEnabled,
                    onChanged: _setAutoSync,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeTrackColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Только по Wi-Fi',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Не синхронизировать через мобильные данные',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _wifiOnly,
                    onChanged: _setWifiOnly,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats card
            _buildCard(
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync, color: _accent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Статус синхронизации',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_isSyncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    Icons.hourglass_empty,
                    'Ожидание',
                    _lastProgress.pending,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.cloud_upload,
                    'Загрузка',
                    _lastProgress.uploading,
                    _accent,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.check_circle,
                    'Готово',
                    _lastProgress.done,
                    Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.error_outline,
                    'Ошибки',
                    _lastProgress.failed,
                    Colors.red,
                  ),
                  if (_isSyncing &&
                      _lastProgress.currentFileProgress > 0) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _lastProgress.currentFileProgress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(_lastProgress.currentFileProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync, color: Colors.white),
                label: const Text(
                  'Синхронизировать сейчас',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSyncing ? null : _startSync,
              ),
            ),

            if (_isSyncing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text(
                    'Остановить',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _stopSync,
                ),
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Сбросить очередь',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _resetQueue,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Color cardColor, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatRow(IconData icon, String label, int count, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}
