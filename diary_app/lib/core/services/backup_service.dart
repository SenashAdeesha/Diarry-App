import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

const _backupVersion = 1;

class BackupManifest {
  final int version;
  final String appVersion;
  final DateTime createdAt;
  final int entryCount;
  final int imageCount;
  final bool isIncremental;
  final DateTime? lastBackupAt;

  const BackupManifest({
    required this.version,
    required this.appVersion,
    required this.createdAt,
    required this.entryCount,
    required this.imageCount,
    this.isIncremental = false,
    this.lastBackupAt,
  });

  String get filename =>
      'diary_backup_${DateFormat('yyyyMMdd_HHmmss').format(createdAt)}.json';

  String get label => DateFormat('MMM d, yyyy – h:mm a').format(createdAt);

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      version: json['version'] as int,
      appVersion: json['app_version'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
      entryCount: (json['entries'] as List).length,
      imageCount: (json['images'] as Map<String, dynamic>?)?.length ?? 0,
      isIncremental: json['is_incremental'] as bool? ?? false,
      lastBackupAt: json['last_backup_at'] != null
          ? DateTime.tryParse(json['last_backup_at'] as String)
          : null,
    );
  }
}

class BackupArchive {
  final BackupManifest manifest;
  final List<Map<String, dynamic>> entries;
  final Map<String, String> images;

  const BackupArchive({
    required this.manifest,
    required this.entries,
    required this.images,
  });
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final _secStorage = const FlutterSecureStorage();
  static const _lastBackupKey = 'last_backup_timestamp';
  static const _autoBackupKey = 'auto_backup_enabled';

  final _localManifests = <BackupManifest>[];

  Future<void> init() async {
    await _refreshLocal();
  }

  Future<bool> isAutoBackupEnabled() async {
    final v = await _secStorage.read(key: _autoBackupKey);
    return v == 'true';
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _secStorage.write(key: _autoBackupKey, value: enabled.toString());
  }

  Future<DateTime?> getLastBackupTime() async {
    final v = await _secStorage.read(key: _lastBackupKey);
    return v != null ? DateTime.tryParse(v) : null;
  }

  List<BackupManifest> get localBackups => List.unmodifiable(_localManifests);

  Future<File> createBackup({
    required List<Map<String, dynamic>> entries,
    Map<String, String> images = const {},
    bool incremental = false,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);

    final lastBackup = incremental ? await getLastBackupTime() : null;

    final data = {
      'version': _backupVersion,
      'app_version': AppConstants.appVersion,
      'created_at': DateTime.now().toIso8601String(),
      'is_incremental': incremental,
      if (lastBackup != null) 'last_backup_at': lastBackup.toIso8601String(),
      'entries': entries,
      'images': images,
    };

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${backupDir.path}/diary_backup_$ts.json');
    await file.writeAsString(jsonEncode(data));

    await _secStorage.write(
        key: _lastBackupKey, value: DateTime.now().toIso8601String());
    await _refreshLocal();

    return file;
  }

  Future<BackupArchive> readBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw BackupException('Backup file not found');
    final raw = await file.readAsString();
    return _parse(raw);
  }

  Future<BackupArchive> readCloudBackup(String cloudPath) async {
    final ref = FirebaseStorage.instance.ref(cloudPath);
    final raw = await ref.getData();
    if (raw == null) throw BackupException('Cloud backup not found');
    return _parse(utf8.decode(raw));
  }

  BackupArchive _parse(String rawJson) {
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    final manifest = BackupManifest.fromJson(data);

    if (manifest.version > _backupVersion) {
      throw BackupException(
          'Backup is from a newer app version. Update the app first.');
    }

    return BackupArchive(
      manifest: manifest,
      entries: (data['entries'] as List)
          .cast<Map<String, dynamic>>(),
      images: (data['images'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          const {},
    );
  }

  Future<void> uploadToCloud(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw BackupException('Not signed in');
    final ref = FirebaseStorage.instance.ref(
        'backups/${user.uid}/${file.uri.pathSegments.last}');
    await ref.putFile(file);
  }

  Future<List<BackupManifest>> listCloudBackups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final ref = FirebaseStorage.instance.ref('backups/${user.uid}');
    final result = await ref.listAll();
    final list = <BackupManifest>[];
    for (final item in result.items) {
      try {
        final raw = await item.getData();
        if (raw != null) {
          list.add(BackupManifest.fromJson(
              jsonDecode(utf8.decode(raw)) as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> deleteCloudBackup(String filename) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseStorage.instance
        .ref('backups/${user.uid}/$filename')
        .delete();
  }

  Future<void> deleteLocalBackup(String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/backups/$filename');
    if (await file.exists()) await file.delete();
    await _refreshLocal();
  }

  Future<void> _refreshLocal() async {
    _localManifests.clear();
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) return;
    final files = await backupDir.list().toList();
    for (final f in files) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          _localManifests.add(BackupManifest.fromJson(
              jsonDecode(await f.readAsString()) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    _localManifests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}
