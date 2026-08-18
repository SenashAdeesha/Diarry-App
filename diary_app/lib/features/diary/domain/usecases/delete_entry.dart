import '../repositories/diary_repository.dart';

class DeleteEntry {
  final DiaryRepository _repository;

  DeleteEntry(this._repository);

  Future<void> call(String id) => _repository.deleteEntry(id);
}
