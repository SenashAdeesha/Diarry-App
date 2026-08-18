import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/auth_service.dart';
import '../../domain/domain_exceptions.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../datasources/diary_local_datasource.dart';
import '../models/diary_entry_model.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  final DiaryLocalDataSource _dataSource;
  final AuthService _auth;

  DiaryRepositoryImpl({
    required DiaryLocalDataSource dataSource,
    AuthService? auth,
  })  : _dataSource = dataSource,
        _auth = auth ?? AuthService.instance;

  @override
  Future<List<DiaryEntry>> getEntries() async {
    try {
      final models = await _dataSource.getAll();
      final entities = models.map((m) => m.toEntity()).toList(growable: false);
      return await Future.wait(entities.map(_decrypt));
    } on CacheException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  @override
  Future<DiaryEntry?> getEntryById(String id) async {
    try {
      final model = await _dataSource.getById(id);
      if (model == null) return null;
      return _decrypt(model.toEntity());
    } on CacheException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  @override
  Future<void> addEntry(DiaryEntry entry) async {
    try {
      final encrypted = await _encrypt(entry);
      await _dataSource.add(DiaryEntryModel.fromEntity(encrypted));
    } on ValidationException {
      rethrow;
    } on CacheException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  @override
  Future<void> updateEntry(DiaryEntry entry) async {
    try {
      final existing = await _dataSource.getById(entry.id);
      if (existing == null) throw const NotFoundException('Entry not found');
      final encrypted = await _encrypt(entry);
      await _dataSource.update(DiaryEntryModel.fromEntity(encrypted));
    } on ValidationException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } on CacheException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    try {
      final existing = await _dataSource.getById(id);
      if (existing == null) throw const NotFoundException('Entry not found');
      await _dataSource.delete(id);
    } on NotFoundException {
      rethrow;
    } on CacheException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  Future<DiaryEntry> _encrypt(DiaryEntry entry) async {
    final encryptedContent = await _auth.encryptContent(entry.content);
    return entry.copyWith(content: encryptedContent);
  }

  Future<DiaryEntry> _decrypt(DiaryEntry entry) async {
    final decryptedContent = await _auth.decryptContent(entry.content);
    return entry.copyWith(content: decryptedContent);
  }
}
