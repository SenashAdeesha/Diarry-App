import '../entities/diary_entry.dart';
import '../repositories/diary_repository.dart';

class AddEntry {
  final DiaryRepository _repository;

  AddEntry(this._repository);

  Future<void> call(DiaryEntry entry) => _repository.addEntry(entry);
}
