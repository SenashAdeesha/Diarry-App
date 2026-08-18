import '../entities/diary_entry.dart';
import '../repositories/diary_repository.dart';

class UpdateEntry {
  final DiaryRepository _repository;

  UpdateEntry(this._repository);

  Future<void> call(DiaryEntry entry) => _repository.updateEntry(entry);
}
