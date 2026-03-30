import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_app/l10n/app_localizations.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

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
  bool _useSelectedFiles = false; // 👈 НОВОЕ

  List<String> _selectedFiles = []; // 👈 НОВОЕ

  TimeOfDay? _syncTime;
  List<int> _syncDays = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
        _wifiOnly = prefs.getBool('auto_sync_wifi_only') ?? false;
        _useSelectedFiles =
            prefs.getBool('auto_sync_selected_only') ?? false;
        _selectedFiles =
            prefs.getStringList('selected_files') ?? [];
        
        final hour = prefs.getInt('sync_time_hour');
        final minute = prefs.getInt('sync_time_minute');
        if (hour != null && minute != null) {
          _syncTime = TimeOfDay(hour: hour, minute: minute);
        }
        
        final daysStr = prefs.getStringList('sync_days') ?? [];
        _syncDays = daysStr.map(int.parse).toList();
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

  Future<void> _setUseSelected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_selected_only', value);

    if (mounted) setState(() => _useSelectedFiles = value);

    if (value) {
      _openFilePicker();
    }
  }

  Future<void> _openFilePicker() async {
    // ⚠️ ЗАГЛУШКА — подключи свой picker
    final files = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryPickerPage(_selectedFiles),
      ),
    );

    if (files != null) {
      setState(() => _selectedFiles = files);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selected_files', files);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _syncTime ?? TimeOfDay.now(),
    );
    if (t != null) {
      setState(() => _syncTime = t);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sync_time_hour', t.hour);
      await prefs.setInt('sync_time_minute', t.minute);
      _scheduleSync();
    }
  }

  Future<void> _toggleDay(int dayIndex) async {
    setState(() {
      if (_syncDays.contains(dayIndex)) {
        _syncDays.remove(dayIndex);
      } else {
        _syncDays.add(dayIndex);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sync_days', _syncDays.map((d) => d.toString()).toList());
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncTime == null || _syncDays.isEmpty) {
      AndroidAlarmManager.cancel(1);
      return;
    }
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, _syncTime!.hour, _syncTime!.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    AndroidAlarmManager.periodic(
      const Duration(days: 1),
      1,
      backgroundSyncCallback,
      startAt: scheduled,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  Future<void> _startSync() async {

    // 👇 используем новый метод
    await _syncService.startAutoSync();
  }

  Future<void> _stopSync() async {
    await _syncService.stopSync();
  }

  Future<void> _resetQueue() async {
    final t = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t.syncResetConfirmTitle),
        content: Text(t.syncResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t.syncResetConfirmButton,
              style: const TextStyle(color: Colors.red),
            ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isRunning = context.watch<SyncNotifier>().isRunning;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(t.syncSettingsTitle),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCard(
              cardColor: cardColor,
              child: Column(
                children: [
                  SwitchListTile(
                    activeTrackColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.syncEnableToggle),
                    subtitle: Text(t.syncAutoUpload),
                    value: _autoSyncEnabled,
                    onChanged: _setAutoSync,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeTrackColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.syncWifiOnly),
                    subtitle: Text(t.syncNoMobileData),
                    value: _wifiOnly,
                    onChanged: _setWifiOnly,
                  ),
                  const Divider(height: 1),

                  // 👇 НОВЫЙ БЛОК
                  SwitchListTile(
                    activeTrackColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Выбранные файлы'),
                    subtitle: const Text(
                        'Синхронизировать только выбранные'),
                    value: _useSelectedFiles,
                    onChanged: _setUseSelected,
                  ),
                  const Divider(height: 1),

                  // 👇 Таймер Авто-Синхронизации
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Время синхронизации'),
                    subtitle: Text(_syncTime != null 
                      ? '${_syncTime!.hour.toString().padLeft(2, '0')}:${_syncTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Не установлено'),
                    trailing: const Icon(Icons.access_time, color: _accent),
                    onTap: _pickTime,
                  ),
                  Wrap(
                    spacing: 4,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final isSelected = _syncDays.contains(day);
                      final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                      return FilterChip(
                        label: Text(dayNames[i], style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: _accent.withValues(alpha: 0.2),
                        checkmarkColor: _accent,
                        onSelected: (_) => _toggleDay(day),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildCard(
              cardColor: cardColor,
              child: Consumer<SyncNotifier>(
                builder: (context, notifier, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sync, color: _accent, size: 20),
                          const SizedBox(width: 8),
                          Text(t.syncStatusTitle),
                          const Spacer(),
                          if (notifier.isRunning)
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

                      _buildStatRow(Icons.hourglass_empty,
                          t.syncStatusPending, notifier.waiting, Colors.orange),

                      const SizedBox(height: 8),

                      _buildStatRow(Icons.check_circle,
                          t.syncStatusDone, notifier.done, Colors.green),

                      const SizedBox(height: 8),

                      if (notifier.isRunning &&
                          notifier.currentFileProgress > 0) ...[
                        const SizedBox(height: 16),

                        if (notifier.currentFileName != null)
                          Text(
                            notifier.currentFileName!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),

                        const SizedBox(height: 6),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: notifier.currentFileProgress,
                            minHeight: 6,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(notifier.currentFileProgress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync, color: Colors.white),
                label: Text(t.syncNowButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: isRunning ? null : _startSync,
              ),
            ),

            if (isRunning) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: Text(t.syncStop),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                label: Text(t.syncResetButton),
                onPressed: _resetQueue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Color cardColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildStatRow(
      IconData icon, String label, int count, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text('$count', style: TextStyle(color: color)),
      ],
    );
  }
}

class _GalleryPickerPage extends StatefulWidget {
  final List<String> initialSelected;
  const _GalleryPickerPage(this.initialSelected);

  @override
  State<_GalleryPickerPage> createState() => _GalleryPickerPageState();
}

class _GalleryPickerPageState extends State<_GalleryPickerPage> {
  final Set<String> _selected = {};
  List<AssetEntity> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;
    
    final albums = await PhotoManager.getAssetPathList(type: RequestType.common);
    if (albums.isNotEmpty) {
      final assets = await albums.first.getAssetListPaged(page: 0, size: 200);
      if (mounted) {
        setState(() {
          _assets = assets;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _selected.toList()),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                final isSelected = _selected.contains(asset.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    isSelected ? _selected.remove(asset.id) : _selected.add(asset.id);
                  }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                        builder: (_, snap) => snap.data != null 
                            ? Image.memory(snap.data!, fit: BoxFit.cover) 
                            : const ColoredBox(color: Colors.grey),
                      ),
                      if (isSelected)
                        Container(
                          color: Colors.black45,
                          child: const Icon(Icons.check_circle, color: Colors.blueAccent, size: 30),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}