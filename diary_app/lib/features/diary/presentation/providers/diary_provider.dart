import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain_exceptions.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../domain/usecases/add_entry.dart';
import '../../domain/usecases/get_entries.dart';
import '../../domain/usecases/delete_entry.dart';
import '../../domain/usecases/update_entry.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/sync_service.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  throw UnimplementedError('Override in main.dart');
});

enum DiaryOperation { load, add, update, delete, none }

class DiaryState {
  final List<DiaryEntry> entries;
  final bool isLoading;
  final DomainException? error;
  final DiaryOperation lastOperation;
  final DiaryEntry? selectedEntry;
  final String? searchQuery;
  final Mood? moodFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  // Memoized filtered + streak cache (internal, not for UI comparison)
  List<DiaryEntry>? _cachedFiltered;
  String? _filterCacheKey;
  int? _cachedStreak;

  DiaryState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
    this.lastOperation = DiaryOperation.none,
    this.selectedEntry,
    this.searchQuery,
    this.moodFilter,
    this.dateFrom,
    this.dateTo,
  });

  List<DiaryEntry> get filteredEntries {
    final key = '${searchQuery ?? ""}|${moodFilter?.name ?? ""}|${dateFrom?.toIso8601String() ?? ""}|${dateTo?.toIso8601String() ?? ""}|${entries.length}';
    if (_cachedFiltered != null && _filterCacheKey == key) return _cachedFiltered!;
    var result = entries;
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final q = searchQuery!.toLowerCase();
      result = result.where((e) =>
          e.title.toLowerCase().contains(q) || e.content.toLowerCase().contains(q))
          .toList(growable: false);
    }
    if (moodFilter != null) {
      result = result.where((e) => e.mood == moodFilter).toList(growable: false);
    }
    if (dateFrom != null) {
      result = result.where((e) => !e.createdAt.isBefore(dateFrom!)).toList(growable: false);
    }
    if (dateTo != null) {
      result = result.where((e) => !e.createdAt.isAfter(dateTo!.add(const Duration(days: 1)))).toList(growable: false);
    }
    _cachedFiltered = result;
    _filterCacheKey = key;
    return result;
  }

  int streak(DiaryEntry entry) {
    if (_cachedStreak != null) return _cachedStreak!;
    _cachedStreak = _computeStreak(entries);
    return _cachedStreak!;
  }

  static int _computeStreak(List<DiaryEntry> entries) {
    if (entries.isEmpty) return 0;
    var expected = DateTime.now();
    int streak = 0;
    for (final e in entries) {
      final d = e.createdAt;
      if (d.year == expected.year &&
          d.month == expected.month &&
          d.day == expected.day) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (d.isBefore(
          DateTime(expected.year, expected.month, expected.day))) {
        break;
      }
    }
    return streak;
  }

  DiaryState copyWith({
    List<DiaryEntry>? entries,
    bool? isLoading,
    Object? error,
    DiaryOperation? lastOperation,
    DiaryEntry? selectedEntry,
    bool clearSelected = false,
    String? searchQuery,
    bool clearSearch = false,
    Mood? moodFilter,
    bool clearMoodFilter = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
  }) {
    return DiaryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: _resolveError(error),
      lastOperation: lastOperation ?? this.lastOperation,
      selectedEntry: clearSelected ? null : (selectedEntry ?? this.selectedEntry),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      moodFilter: clearMoodFilter ? null : (moodFilter ?? this.moodFilter),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }

  DomainException? _resolveError(Object? error) {
    if (error == null) return null;
    if (error is DomainException) return error;
    if (error is String) return RepositoryException(error);
    return RepositoryException(error.toString());
  }
}

class DiaryNotifier extends StateNotifier<DiaryState> {
  final DiaryRepository _repository;

  late final GetEntries _getEntries;
  late final AddEntry _addEntry;
  late final UpdateEntry _updateEntry;
  late final DeleteEntry _deleteEntry;

  DiaryNotifier(this._repository) : super(DiaryState()) {
    _getEntries = GetEntries(_repository);
    _addEntry = AddEntry(_repository);
    _updateEntry = UpdateEntry(_repository);
    _deleteEntry = DeleteEntry(_repository);
  }

  Future<void> loadEntries() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final entries = await _getEntries();
      state = state.copyWith(
        entries: entries,
        isLoading: false,
        lastOperation: DiaryOperation.load,
      );
    } on DomainException catch (e) {
      state = state.copyWith(isLoading: false, error: e, lastOperation: DiaryOperation.load);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: RepositoryException('Unexpected error: $e'),
        lastOperation: DiaryOperation.load,
      );
    }
  }

  Future<void> addEntry(DiaryEntry entry) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _addEntry(entry);
      state = state.copyWith(
        entries: [entry, ...state.entries],
        isLoading: false,
        lastOperation: DiaryOperation.add,
      );
      _checkStreak();
      SyncService.instance.requestSync();
    } on DomainException catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: RepositoryException('Failed to add entry: $e'),
      );
    }
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _updateEntry(entry);
      state = state.copyWith(
        entries: state.entries.map((e) => e.id == entry.id ? entry : e).toList(growable: false),
        isLoading: false,
        lastOperation: DiaryOperation.update,
      );
      _checkStreak();
      SyncService.instance.requestSync();
    } on NotFoundException {
      state = state.copyWith(
        isLoading: false,
        error: const RepositoryException('Entry was deleted. Refresh.'),
      );
    } on DomainException catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: RepositoryException('Failed to update entry: $e'),
      );
    }
  }

  Future<void> deleteEntry(String id) async {
    final entryIndex = state.entries.indexWhere((e) => e.id == id);
    if (entryIndex == -1) return;
    final previousEntries = state.entries;
    state = state.copyWith(
      entries: [...state.entries]..removeAt(entryIndex),
      isLoading: true,
      error: null,
    );
    try {
      await _deleteEntry(id);
      state = state.copyWith(isLoading: false, lastOperation: DiaryOperation.delete);
      SyncService.instance.requestSync();
    } on NotFoundException {
      state = state.copyWith(entries: previousEntries, isLoading: false,
          error: const RepositoryException('Entry was already deleted.'));
    } on DomainException catch (e) {
      state = state.copyWith(entries: previousEntries, isLoading: false, error: e);
    } catch (e) {
      state = state.copyWith(entries: previousEntries, isLoading: false,
          error: RepositoryException('Failed to delete entry: $e'));
    }
  }

  void selectEntry(DiaryEntry? entry) => state = state.copyWith(selectedEntry: entry);

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      clearSearch: query.isEmpty,
    );
  }

  void setMoodFilter(Mood? mood) {
    state = state.copyWith(moodFilter: mood, clearMoodFilter: mood == null);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
    );
  }

  void clearFilters() => state = state.copyWith(
    clearSearch: true,
    clearMoodFilter: true,
    clearDateFrom: true,
    clearDateTo: true,
  );

  void clearError() => state = state.copyWith(error: null);

  void _checkStreak() {
    final s = DiaryState._computeStreak(state.entries);
    if (s >= 3) NotificationService.instance.checkStreakAndNotify(s);
  }
}

final diaryNotifierProvider = StateNotifierProvider<DiaryNotifier, DiaryState>(
  (ref) => DiaryNotifier(ref.watch(diaryRepositoryProvider)),
  dependencies: [diaryRepositoryProvider],
);
