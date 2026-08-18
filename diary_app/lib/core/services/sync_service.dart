import 'dart:async';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/diary/data/datasources/diary_local_datasource.dart';
import '../../features/diary/data/datasources/remote/diary_remote_datasource.dart';
import '../../features/diary/data/models/diary_entry_model.dart';
import '../../features/diary/domain/entities/diary_entry.dart';
import '../../features/diary/domain/repositories/diary_repository.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSync;
  final int pushed;
  final int pulled;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSync,
    this.pushed = 0,
    this.pulled = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSync,
    int? pushed,
    int? pulled,
  }) =>
      SyncState(
        status: status ?? this.status,
        message: message ?? this.message,
        lastSync: lastSync ?? this.lastSync,
        pushed: pushed ?? this.pushed,
        pulled: pulled ?? this.pulled,
      );
}

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _storage = const FlutterSecureStorage();
  static const _lastSyncKey = 'last_sync_timestamp';

  final _stateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState _state = const SyncState();
  SyncState get currentState => _state;

  DiaryLocalDataSource? _localDataSource;
  DiaryRemoteDataSource? _remoteDataSource;

  bool _initialized = false;
  Timer? _debounceTimer;
  bool _isSyncing = false;

  static const _batchLimit = 500;

  void init({
    required DiaryRepository repository,
    required DiaryLocalDataSource localDataSource,
    required DiaryRemoteDataSource remoteDataSource,
  }) {
    _localDataSource = localDataSource;
    _remoteDataSource = remoteDataSource;
    _initialized = true;
  }

  Future<void> signInAnonymously() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {}
  }

  Future<bool> isSignedIn() async => FirebaseAuth.instance.currentUser != null;

  Future<DateTime?> getLastSyncTimestamp() async {
    final raw = await _storage.read(key: _lastSyncKey);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> _saveLastSync(DateTime time) async {
    await _storage.write(key: _lastSyncKey, value: time.toIso8601String());
  }

  Future<void> requestSync({Duration debounce = const Duration(seconds: 3)}) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => sync());
  }

  Future<void> sync() async {
    if (!_initialized || _isSyncing) return;
    _isSyncing = true;

    await signInAnonymously();
    if (!await isSignedIn()) {
      _isSyncing = false;
      return;
    }

    _emit(_state.copyWith(status: SyncStatus.syncing));

    try {
      final result = await _performSync();
      await _saveLastSync(result.syncTime);
      _emit(_state.copyWith(
        status: SyncStatus.success,
        lastSync: result.syncTime,
        pushed: result.pushed,
        pulled: result.pulled,
      ));
    } catch (e) {
      _emit(_state.copyWith(status: SyncStatus.error, message: e.toString()));
    }

    _debounceTimer?.cancel();
    _isSyncing = false;
  }

  Future<_SyncResult> _performSync() async {
    final lastSync = await getLastSyncTimestamp() ??
        DateTime.now().subtract(const Duration(days: 30));

    int pushed = 0;
    int pulled = 0;

    final localModified = await _localDataSource!.getModifiedSince(lastSync);
    final remoteEntries = await _remoteDataSource!.pullNewerThan(lastSync);

    if (remoteEntries.isNotEmpty) {
      pulled = remoteEntries.length;
      await _mergeRemote(remoteEntries, lastSync);
    }

    if (localModified.isNotEmpty) {
      final toPush = localModified.map((m) => m.toEntity()).toList(growable: false);
      for (var i = 0; i < toPush.length; i += _batchLimit) {
        final batch = toPush.sublist(i, (i + _batchLimit).clamp(0, toPush.length));
        await _remoteDataSource!.pushBatch(batch);
        pushed += batch.length;
      }
    }

    return _SyncResult(syncTime: DateTime.now(), pushed: pushed, pulled: pulled);
  }

  Future<void> _mergeRemote(List<DiaryEntry> remoteEntries, DateTime lastSync) async {
    final localAll = await _localDataSource!.getAll();
    final localMap = HashMap<String, DiaryEntryModel>.fromIterables(
      localAll.map((e) => e.id),
      localAll,
    );

    for (final remote in remoteEntries) {
      final local = localMap[remote.id];
      if (local == null) {
        await _localDataSource!.add(DiaryEntryModel.fromEntity(remote));
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        await _localDataSource!.update(DiaryEntryModel.fromEntity(remote));
      }
    }
  }

  Future<int> fullPull() async {
    if (!_initialized) return 0;
    try {
      final remote = await _remoteDataSource!.pullNewerThan(DateTime(2000, 1, 1));
      for (final entry in remote) {
        await _localDataSource!.add(DiaryEntryModel.fromEntity(entry));
      }
      await _saveLastSync(DateTime.now());
      return remote.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> reset() async {
    _debounceTimer?.cancel();
    await _storage.delete(key: _lastSyncKey);
    _emit(const SyncState());
  }

  void dispose() {
    _debounceTimer?.cancel();
    _stateController.close();
    _isSyncing = false;
  }

  void _emit(SyncState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}

class _SyncResult {
  final DateTime syncTime;
  final int pushed;
  final int pulled;
  const _SyncResult({required this.syncTime, required this.pushed, required this.pulled});
}
