import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

enum HiveInitStatus { uninitialized, initializing, ready, failed }

final class HiveInitResult {
  final bool success;
  final String? error;
  const HiveInitResult(this.success, {this.error});
}

typedef AdapterRegistration = void Function();

class HiveService {
  static final HiveService instance = HiveService._();
  HiveService._();

  HiveInitStatus _status = HiveInitStatus.uninitialized;
  String? _lastError;
  final _openBoxes = <String, Box>{};
  final _adapterRegistry = <AdapterRegistration>[];
  Future<HiveInitResult>? _initFuture;

  HiveInitStatus get status => _status;
  String? get lastError => _lastError;
  bool get isReady => _status == HiveInitStatus.ready;

  void registerAdapter(AdapterRegistration registration) {
    if (_status == HiveInitStatus.ready) {
      try {
        registration();
      } catch (_) {}
    } else {
      _adapterRegistry.add(registration);
    }
  }

  Future<HiveInitResult> init({String? customPath}) async {
    if (_status == HiveInitStatus.ready) return const HiveInitResult(true);
    if (_initFuture != null) return await _initFuture!;

    _initFuture = _doInit(customPath);
    return await _initFuture!;
  }

  Future<HiveInitResult> _doInit(String? customPath) async {
    _status = HiveInitStatus.initializing;
    try {
      final path = customPath ?? (await getApplicationDocumentsDirectory()).path;
      await Hive.initFlutter(path);
      for (final register in _adapterRegistry) {
        try {
          register();
        } catch (_) {}
      }
      _adapterRegistry.clear();
      _status = HiveInitStatus.ready;
      return const HiveInitResult(true);
    } catch (e) {
      _status = HiveInitStatus.failed;
      _lastError = e.toString();
      return HiveInitResult(false, error: _lastError);
    }
  }

  Future<Box<T>> openBox<T>(
    String name, {
    bool lazy = false,
    bool clearOnFail = false,
  }) async {
    if (_status != HiveInitStatus.ready) {
      final result = await init();
      if (!result.success) {
        throw StateError('Hive failed to initialize: ${result.error}');
      }
    }

    if (_openBoxes.containsKey(name)) {
      return _openBoxes[name]! as Box<T>;
    }

    try {
      final box = await Hive.openBox<T>(name);
      _openBoxes[name] = box;
      return box;
    } on HiveError {
      if (clearOnFail) {
        await Hive.deleteBoxFromDisk(name);
        final box = await Hive.openBox<T>(name);
        _openBoxes[name] = box;
        return box;
      }
      rethrow;
    }
  }

  Box<T>? getBox<T>(String name) => _openBoxes[name] as Box<T>?;

  bool isBoxOpen(String name) => _openBoxes.containsKey(name);

  Future<void> closeBox(String name) async {
    final box = _openBoxes.remove(name);
    if (box != null) await box.close();
  }

  Future<void> closeAll() async {
    for (final name in _openBoxes.keys.toList()) {
      await closeBox(name);
    }
    await Hive.close();
    _status = HiveInitStatus.uninitialized;
    _initFuture = null;
  }

  Future<void> deleteBox(String name) async {
    await closeBox(name);
    await Hive.deleteBoxFromDisk(name);
  }
}
