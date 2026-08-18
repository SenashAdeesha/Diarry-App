import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/domain_exceptions.dart';
import '../../domain/entities/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../widgets/diary_card.dart';
import 'editor_screen.dart';
import 'diary_detail_screen.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  bool _showFilters = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(diaryNotifierProvider.notifier).loadEntries(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(diaryNotifierProvider.notifier).setSearchQuery(query);
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: ref.read(diaryNotifierProvider).dateFrom ?? now.subtract(const Duration(days: 30)),
        end: ref.read(diaryNotifierProvider).dateTo ?? now,
      ),
    );
    if (range != null) {
      ref.read(diaryNotifierProvider.notifier).setDateRange(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(diaryNotifierProvider.select((s) => s.isLoading));
    final error = ref.watch(diaryNotifierProvider.select((s) => s.error));
    final searchQuery = ref.watch(diaryNotifierProvider.select((s) => s.searchQuery));
    final moodFilter = ref.watch(diaryNotifierProvider.select((s) => s.moodFilter));
    final dateFrom = ref.watch(diaryNotifierProvider.select((s) => s.dateFrom));
    final dateTo = ref.watch(diaryNotifierProvider.select((s) => s.dateTo));
    final entries = ref.watch(diaryNotifierProvider.select((s) {
      if (s.searchQuery != null || s.moodFilter != null || s.dateFrom != null || s.dateTo != null) {
        return s.filteredEntries;
      }
      return s.entries;
    }));
    final hasActiveFilters = searchQuery != null || moodFilter != null || dateFrom != null || dateTo != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            toolbarHeight: 72,
            title: _showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search entries...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: _onSearchChanged)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Memories',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${entries.length} entries',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
            actions: [
              if (hasActiveFilters)
                IconButton(
                  icon: Icon(Icons.filter_alt, color: theme.colorScheme.primary),
                  onPressed: () => ref.read(diaryNotifierProvider.notifier).clearFilters(),
                ),
              IconButton(
                icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt_outlined,
                    color: moodFilter != null || dateFrom != null ? theme.colorScheme.primary : null),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      ref.read(diaryNotifierProvider.notifier).clearFilters();
                    }
                  });
                },
              ),
            ],
          ),
          if (_showFilters)
            SliverToBoxAdapter(child: _buildFilterPanel(theme)),
          if (hasActiveFilters && !_showFilters)
            SliverToBoxAdapter(child: _buildActiveFilters(theme, searchQuery, moodFilter, dateFrom, dateTo)),
          _buildBody(entries, isLoading, error, searchQuery, theme),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditorScreen()));
          ref.read(diaryNotifierProvider.notifier).loadEntries();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Entry saved'), duration: Duration(seconds: 1)),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    final currentMood = ref.watch(diaryNotifierProvider.select((s) => s.moodFilter));
    final currentFrom = ref.watch(diaryNotifierProvider.select((s) => s.dateFrom));
    final currentTo = ref.watch(diaryNotifierProvider.select((s) => s.dateTo));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Filter by', style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(diaryNotifierProvider.notifier).clearFilters(),
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...Mood.values.map((mood) {
                  final selected = mood == currentMood;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      onSelected: (_) {
                        ref.read(diaryNotifierProvider.notifier)
                            .setMoodFilter(selected ? null : mood);
                      },
                      avatar: Icon(_moodIcon(mood), size: 16,
                          color: selected ? Colors.white : AppColors.moodColor(mood.name)),
                      label: Text(mood.name[0].toUpperCase() + mood.name.substring(1)),
                      selectedColor: AppColors.moodColor(mood.name),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ActionChip(
                    avatar: Icon(Icons.date_range, size: 16,
                        color: currentFrom != null ? Colors.white : theme.colorScheme.primary),
                    label: Text(currentFrom != null
                        ? '${DateFormat('MMM d').format(currentFrom!)} - ${DateFormat('MMM d').format(currentTo ?? DateTime.now())}'
                        : 'Date range'),
                    onPressed: _pickDateRange,
                    color: WidgetStatePropertyAll(currentFrom != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest),
                    labelStyle: WidgetStateTextStyle.resolveWith((states) =>
                        TextStyle(color: currentFrom != null ? Colors.white : null)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(ThemeData theme, String? searchQuery, Mood? moodFilter,
      DateTime? dateFrom, DateTime? dateTo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (searchQuery != null && searchQuery.isNotEmpty)
            _filterChip(theme, Icons.search, '"$searchQuery"', theme.colorScheme.secondaryContainer,
                theme.colorScheme.onSecondaryContainer, () {
              _searchController.clear();
              ref.read(diaryNotifierProvider.notifier).clearFilters();
            }),
          if (moodFilter != null)
            _filterChip(theme, _moodIcon(moodFilter),
                moodFilter.name[0].toUpperCase() + moodFilter.name.substring(1),
                AppColors.moodColor(moodFilter.name).withValues(alpha: 0.15),
                AppColors.moodColor(moodFilter.name), () {
              ref.read(diaryNotifierProvider.notifier).setMoodFilter(null);
            }),
          if (dateFrom != null)
            _filterChip(theme, Icons.date_range,
                '${DateFormat('MMM d').format(dateFrom)} - ${DateFormat('MMM d').format(dateTo ?? DateTime.now())}',
                theme.colorScheme.tertiaryContainer,
                theme.colorScheme.onTertiaryContainer, () {
              ref.read(diaryNotifierProvider.notifier).setDateRange(null, null);
            }),
        ],
      ),
    );
  }

  Widget _filterChip(ThemeData theme, IconData icon, String label, Color bg, Color fg, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 14, color: fg)),
      ]),
    );
  }

  Widget _buildBody(List<DiaryEntry> entries, bool isLoading, DomainException? error,
      String? searchQuery, ThemeData theme) {
    if (isLoading && entries.isEmpty) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }

    if (error != null && entries.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(diaryNotifierProvider.notifier).loadEntries(),
              icon: const Icon(Icons.refresh), label: const Text('Retry'),
            ),
          ]),
        )),
      );
    }

    if (entries.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: searchQuery != null ||
            ref.read(diaryNotifierProvider).moodFilter != null ||
            ref.read(diaryNotifierProvider).dateFrom != null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('No matching entries', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('Try adjusting your filters',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.menu_book_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No entries yet', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Tap + to write your first entry',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = entries[index];
            return DiaryCard(
              entry: entry,
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: entry)));
                ref.read(diaryNotifierProvider.notifier).loadEntries();
              },
              onEdit: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EditorScreen(existingEntry: entry)));
                ref.read(diaryNotifierProvider.notifier).loadEntries();
              },
              onDelete: () {
                ref.read(diaryNotifierProvider.notifier).deleteEntry(entry.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${entry.title}" deleted'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          },
          childCount: entries.length,
        ),
      ),
    );
  }

  IconData _moodIcon(Mood m) => switch (m) {
        Mood.happy => Icons.emoji_emotions,
        Mood.sad => Icons.sentiment_dissatisfied,
        Mood.angry => Icons.mood_bad,
        Mood.calm => Icons.self_improvement,
        Mood.anxious => Icons.sentiment_neutral,
        Mood.neutral => Icons.sentiment_satisfied,
      };
}
