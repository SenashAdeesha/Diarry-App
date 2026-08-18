import '../entities/diary_entry.dart';
import '../repositories/diary_repository.dart';

class GetEntries {
  final DiaryRepository _repository;

  GetEntries(this._repository);

  Future<List<DiaryEntry>> call() => _repository.getEntries();
}
