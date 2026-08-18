import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/backup_service.dart';
import '../../../diary/data/models/diary_entry_model.dart';
import '../../../diary/presentation/providers/diary_provider.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/constants/app_constants.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  final _svc = BackupService.instance;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  List<BackupManifest> _cloudBackups = [];
  bool _loadingCloud = false;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _svc.init();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final t = await _svc.getLastBackupTime();
    if (mounted) setState(() => _lastBackup = t);
  }

  Future<void> _doBackup({bool incremental = false}) async {
    setState(() => _isBackingUp = true);
    try {
      final entries = _collectEntries();
      final file = await _svc.createBackup(
        entries: entries,
        incremental: incremental,
      );

      try {
        await _svc.uploadToCloud(file);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _doRestore() async {
    final local = _svc.localBackups;
    if (local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local backups found')),
      );
      return;
    }

    final selected = await showModalBottomSheet<BackupManifest>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select a backup to restore',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...local.map((m) => ListTile(
                  leading: const Icon(Icons.restore_page),
                  title: Text(m.label),
                  subtitle: Text(
                      '${m.entryCount} entries, ${m.imageCount} images'),
                  onTap: () => Navigator.pop(ctx, m),
                )),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final path = '${appDir.path}/backups/${selected.filename}';
      final archive = await _svc.readBackup(path);

      await _restoreEntries(archive.entries);
      await _restoreImages(archive.images);

      ref.read(diaryNotifierProvider.notifier).loadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Restored ${archive.entries.length} entries from ${selected.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  List<Map<String, dynamic>> _collectEntries() {
    final state = ref.read(diaryNotifierProvider);
    return state.entries.map((e) => {
      'id': e.id,
      'title': e.title,
      'content': e.content,
      'created_at': e.createdAt.toIso8601String(),
      'updated_at': e.updatedAt.toIso8601String(),
      'mood': e.mood.name,
      'tags': e.tags,
      'is_favorite': e.isFavorite,
      'image_paths': e.imagePaths,
    }).toList();
  }

  Future<void> _restoreEntries(List<Map<String, dynamic>> entries) async {
    final box = await HiveService.instance
        .openBox<DiaryEntryModel>(AppConstants.hiveBoxName);

    for (final entryData in entries) {
      final id = entryData['id'] as String;
      final existing = box.get(id);

      final backupTime = DateTime.parse(entryData['updated_at'] as String);
      if (existing != null && !backupTime.isAfter(existing.updatedAt)) continue;

      final model = DiaryEntryModel(
        id: id,
        title: entryData['title'] as String,
        content: entryData['content'] as String,
        createdAt: DateTime.parse(entryData['created_at'] as String),
        updatedAt: backupTime,
        mood: entryData['mood'] as String? ?? 'neutral',
        tags: (entryData['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        isFavorite: entryData['is_favorite'] as bool? ?? false,
        imagePaths: (entryData['image_paths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
      await box.put(id, model);
    }
  }

  Future<void> _restoreImages(Map<String, String> images) async {
    if (images.isEmpty) return;
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/${AppConstants.imageDirName}');
    if (!await imageDir.exists()) await imageDir.create(recursive: true);
    for (final e in images.entries) {
      final file = File('${imageDir.path}/${e.key}');
      if (!await file.exists()) {
        await file.writeAsBytes(base64Decode(e.value));
      }
    }
  }

  Future<void> _refreshCloud() async {
    setState(() => _loadingCloud = true);
    try {
      _cloudBackups = await _svc.listCloudBackups();
    } catch (_) {
      _cloudBackups = [];
    }
    if (mounted) setState(() => _loadingCloud = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = _svc.localBackups;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.backup,
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Backup',
                              style: theme.textTheme.titleSmall),
                          Text(
                            _lastBackup != null
                                ? DateFormat('MMM d, yyyy – h:mm a')
                                    .format(_lastBackup!)
                                : 'Never',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _isBackingUp ? null : () => _doBackup(),
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                              _isBackingUp ? 'Backing up...' : 'Back Up Now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _isRestoring ? null : _doRestore,
                          icon: _isRestoring
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.restore_page),
                          label: Text(
                              _isRestoring ? 'Restoring...' : 'Restore'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSection('Local Backups (${local.length})', theme),
          if (local.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No local backups',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ),
            )
          else
            ...local.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.backup),
                    title: Text(m.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        '${m.entryCount} entries • ${m.imageCount} images${m.isIncremental ? ' • incremental' : ''}',
                        style: theme.textTheme.labelSmall),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _svc.deleteLocalBackup(m.filename),
                    ),
                  ),
                )),
          const SizedBox(height: 20),
          _buildSection('Cloud Backups', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Firebase Storage',
                            style: theme.textTheme.bodyMedium),
                      ),
                      TextButton.icon(
                        onPressed: _loadingCloud ? null : _refreshCloud,
                        icon: _loadingCloud
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  if (_cloudBackups.isEmpty && !_loadingCloud)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No cloud backups',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  else
                    ..._cloudBackups.map((m) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.cloud, size: 20),
                          title: Text(m.label,
                              style: theme.textTheme.bodySmall),
                          subtitle: Text(
                              '${m.entryCount} entries',
                              style: theme.textTheme.labelSmall),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () =>
                                _svc.deleteCloudBackup(m.filename),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSection('Settings', theme),
          Card(
            child: _AutoBackupTile(service: _svc),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary)),
    );
  }
}

class _AutoBackupTile extends StatefulWidget {
  final BackupService service;
  const _AutoBackupTile({required this.service});

  @override
  State<_AutoBackupTile> createState() => _AutoBackupTileState();
}

class _AutoBackupTileState extends State<_AutoBackupTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.service.isAutoBackupEnabled();
    if (mounted) setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Auto Backup'),
      subtitle: const Text('Automatically back up data periodically'),
      value: _enabled,
      onChanged: (v) {
        setState(() => _enabled = v);
        widget.service.setAutoBackupEnabled(v);
      },
    );
  }
}
