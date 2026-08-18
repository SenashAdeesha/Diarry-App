import 'package:hive/hive.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/diary_entry_model.dart';

abstract class DiaryLocalDataSource {
  Future<List<DiaryEntryModel>> getAll();

  Future<DiaryEntryModel?> getById(String id);

  Future<int> count();

  Future<void> add(DiaryEntryModel entry);

  Future<void> addMany(List<DiaryEntryModel> entries);

  Future<void> update(DiaryEntryModel entry);

  Future<void> delete(String id);

  Future<void> deleteAll(Iterable<String> ids);

  Future<void> clear();

  Future<List<DiaryEntryModel>> getModifiedSince(DateTime since);
}

class DiaryLocalDataSourceImpl implements DiaryLocalDataSource {
  final Box<DiaryEntryModel> _box;

  DiaryLocalDataSourceImpl(this._box);

  @override
  Future<List<DiaryEntryModel>> getAll() async {
    try {
      final values = _box.values;
      final sorted = values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    } catch (e) {
      throw CacheException('Failed to read entries: $e');
    }
  }

  @override
  Future<DiaryEntryModel?> getById(String id) async {
    try {
      return _box.get(id);
    } catch (e) {
      throw CacheException('Failed to read entry $id: $e');
    }
  }

  @override
  Future<int> count() async {
    try {
      return _box.length;
    } catch (e) {
      throw CacheException('Failed to count entries: $e');
    }
  }

  @override
  Future<void> add(DiaryEntryModel entry) async {
    try {
      await _box.put(entry.id, entry);
    } catch (e) {
      throw CacheException('Failed to save entry: $e');
    }
  }

  @override
  Future<void> addMany(List<DiaryEntryModel> entries) async {
    try {
      final map = {for (final e in entries) e.id: e};
      await _box.putAll(map);
    } catch (e) {
      throw CacheException('Failed to save ${entries.length} entries: $e');
    }
  }

  @override
  Future<void> update(DiaryEntryModel entry) async {
    try {
      await _box.put(entry.id, entry);
    } catch (e) {
      throw CacheException('Failed to update entry: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw CacheException('Failed to delete entry $id: $e');
    }
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    try {
      await _box.deleteAll(ids);
    } catch (e) {
      throw CacheException('Failed to delete ${ids.length} entries: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _box.clear();
    } catch (e) {
      throw CacheException('Failed to clear entries: $e');
    }
  }

  @override
  Future<List<DiaryEntryModel>> getModifiedSince(DateTime since) async {
    try {
      return _box.values
          .where((e) => e.updatedAt.isAfter(since))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      throw CacheException('Failed to query modified entries: $e');
    }
  }
}

class DiaryLocalDataSourceDecorator implements DiaryLocalDataSource {
  final DiaryLocalDataSource _inner;
  final void Function(String message)? onError;

  DiaryLocalDataSourceDecorator(this._inner, {this.onError});

  @override
  Future<List<DiaryEntryModel>> getAll() => _wrap(() => _inner.getAll());

  @override
  Future<DiaryEntryModel?> getById(String id) =>
      _wrap(() => _inner.getById(id));

  @override
  Future<int> count() => _wrap(_inner.count);

  @override
  Future<void> add(DiaryEntryModel entry) =>
      _wrap(() => _inner.add(entry));

  @override
  Future<void> addMany(List<DiaryEntryModel> entries) =>
      _wrap(() => _inner.addMany(entries));

  @override
  Future<void> update(DiaryEntryModel entry) =>
      _wrap(() => _inner.update(entry));

  @override
  Future<void> delete(String id) => _wrap(() => _inner.delete(id));

  @override
  Future<void> deleteAll(Iterable<String> ids) =>
      _wrap(() => _inner.deleteAll(ids));

  @override
  Future<void> clear() => _wrap(_inner.clear);

  @override
  Future<List<DiaryEntryModel>> getModifiedSince(DateTime since) =>
      _wrap(() => _inner.getModifiedSince(since));

  Future<T> _wrap<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on CacheException catch (e) {
      onError?.call(e.message);
      rethrow;
    }
  }
}
