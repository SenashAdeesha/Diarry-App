import '../entities/diary_entry.dart';

abstract class DiaryRepository {
  Future<List<DiaryEntry>> getEntries();

  Future<DiaryEntry?> getEntryById(String id);

  Future<void> addEntry(DiaryEntry entry);

  Future<void> updateEntry(DiaryEntry entry);

  Future<void> deleteEntry(String id);
}
