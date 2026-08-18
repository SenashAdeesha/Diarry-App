import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/diary_entry.dart';
import '../providers/diary_provider.dart';
import 'diary_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Map<DateTime, List<DiaryEntry>> _groupByDay(List<DiaryEntry> entries) {
    final map = <DateTime, List<DiaryEntry>>{};
    for (final e in entries) {
      final day = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  List<DiaryEntry> _entriesForDay(
      DateTime day, Map<DateTime, List<DiaryEntry>> grouped) {
    return grouped[day] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(diaryNotifierProvider);
    final grouped = _groupByDay(state.entries);

    final now = DateTime.now();
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMMM yyyy').format(_focusedMonth),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(
              () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
                () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
          ),
          if (_focusedMonth.month != now.month || _focusedMonth.year != now.year)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () =>
                  setState(() => _focusedMonth = DateTime(now.year, now.month)),
            ),
        ],
      ),
      body: _selectedDay != null && _entriesForDay(_selectedDay!, grouped).isNotEmpty
          ? Column(
              children: [
                _buildCalendar(now, firstDay, firstWeekday, daysInMonth, grouped, theme),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    DateFormatter.instance.formatFull(_selectedDay!),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: _buildDayEntries(
                      _entriesForDay(_selectedDay!, grouped), theme),
                ),
              ],
            )
          : _buildCalendar(now, firstDay, firstWeekday, daysInMonth, grouped, theme),
    );
  }

  Widget _buildCalendar(
    DateTime now,
    DateTime firstDay,
    int firstWeekday,
    int daysInMonth,
    Map<DateTime, List<DiaryEntry>> grouped,
    ThemeData theme,
  ) {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: weekdays
                .map((d) => Expanded(
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox();
              final day = index - firstWeekday + 1;
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final entries = _entriesForDay(date, grouped);
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isSelected = _selectedDay != null &&
                  _selectedDay!.year == date.year &&
                  _selectedDay!.month == date.month &&
                  _selectedDay!.day == date.day;

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                            color: theme.colorScheme.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                          )),
                      if (entries.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: entries
                              .take(3)
                              .map((e) => Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(right: 1.5),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.moodColor(e.mood.name),
                                      shape: BoxShape.circle,
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayEntries(List<DiaryEntry> entries, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.circle,
                size: 12, color: AppColors.moodColor(entry.mood.name)),
            title:
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(entry.content,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(DateFormatter.instance.formatTime(entry.createdAt),
                style: theme.textTheme.labelSmall),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiaryDetailScreen(entry: entry),
                ),
              );
              ref.read(diaryNotifierProvider.notifier).loadEntries();
            },
          ),
        );
      },
    );
  }
}
