import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/diary_entry.dart';
import 'diary_provider.dart';

class AnalyticsData {
  final int totalEntries;
  final int currentStreak;
  final int entriesToday;
  final int entriesThisWeek;
  final int entriesThisMonth;
  final Map<Mood, int> moodDistribution;
  final List<MoodTrendPoint> moodTrend;
  final List<DayEntryCount> entriesPerDay;
  final List<TagCount> topTags;
  final Mood? mostCommonMood;

  const AnalyticsData({
    this.totalEntries = 0,
    this.currentStreak = 0,
    this.entriesToday = 0,
    this.entriesThisWeek = 0,
    this.entriesThisMonth = 0,
    this.moodDistribution = const {},
    this.moodTrend = const [],
    this.entriesPerDay = const [],
    this.topTags = const [],
    this.mostCommonMood,
  });
}

class MoodTrendPoint {
  final DateTime weekStart;
  final double avgMoodValue;
  final int entryCount;
  const MoodTrendPoint({
    required this.weekStart,
    required this.avgMoodValue,
    required this.entryCount,
  });
}

class DayEntryCount {
  final DateTime date;
  final int count;
  const DayEntryCount({required this.date, required this.count});
}

class TagCount {
  final String tag;
  final int count;
  const TagCount({required this.tag, required this.count});
}

const _moodValues = {
  Mood.angry: 0.0,
  Mood.sad: 1.0,
  Mood.anxious: 2.0,
  Mood.neutral: 3.0,
  Mood.calm: 4.0,
  Mood.happy: 5.0,
};

final analyticsProvider = Provider<AnalyticsData>(
  (ref) {
    final state = ref.watch(diaryNotifierProvider);
    return _computeAnalytics(state.entries);
  },
  dependencies: [diaryNotifierProvider],
);

AnalyticsData _computeAnalytics(List<DiaryEntry> entries) {
  if (entries.isEmpty) return const AnalyticsData();

  final totalEntries = entries.length;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int entriesToday = 0;
  int entriesThisWeek = 0;
  int entriesThisMonth = 0;
  final moodCounts = <Mood, int>{};
  final tagCounts = <String, int>{};
  final entryDates = <DateTime, int>{};

  for (final entry in entries) {
    final day = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );

    moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    for (final tag in entry.tags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
    entryDates[day] = (entryDates[day] ?? 0) + 1;

    if (day == today) entriesToday++;
    if (day.isAfter(today.subtract(const Duration(days: 7)))) entriesThisWeek++;
    if (!day.isBefore(DateTime(now.year, now.month, 1))) entriesThisMonth++;
  }

  MapEntry<Mood, int>? mostCommon;
  for (final e in moodCounts.entries) {
    if (mostCommon == null || e.value > mostCommon.value) mostCommon = e;
  }

  return AnalyticsData(
    totalEntries: totalEntries,
    currentStreak: _streak(entries),
    entriesToday: entriesToday,
    entriesThisWeek: entriesThisWeek,
    entriesThisMonth: entriesThisMonth,
    moodDistribution: Map.unmodifiable(moodCounts),
    moodTrend: _buildMoodTrend(entries),
    entriesPerDay: _buildEntriesPerDay(entryDates, now),
    topTags: tagCounts.entries
        .map((e) => TagCount(tag: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count))
      ..take(10).toList(growable: false),
    mostCommonMood: mostCommon?.key,
  );
}

int _streak(List<DiaryEntry> entries) {
  if (entries.isEmpty) return 0;
  var expected = DateTime.now();
  int streak = 0;
  for (final e in entries) {
    final d = e.createdAt;
    if (d.year == expected.year && d.month == expected.month && d.day == expected.day) {
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    } else if (d.isBefore(DateTime(expected.year, expected.month, expected.day))) {
      break;
    }
  }
  return streak;
}

List<MoodTrendPoint> _buildMoodTrend(List<DiaryEntry> entries, {int weeks = 12}) {
  final now = DateTime.now();
  final start = now.subtract(Duration(days: 7 * weeks));
  final weekData = <int, List<double>>{};

  for (final entry in entries) {
    if (entry.createdAt.isBefore(start)) continue;
    final wn = _weekNumber(entry.createdAt);
    (weekData.putIfAbsent(wn, () => []))
        .add(_moodValues[entry.mood] ?? 3.0);
  }

  final result = <MoodTrendPoint>[];
  for (int w = 0; w < weeks; w++) {
    final date = start.add(Duration(days: 7 * w));
    final wn = _weekNumber(date);
    final values = weekData[wn];
    if (values != null && values.isNotEmpty) {
      result.add(MoodTrendPoint(
        weekStart: _dateFromWeek(wn),
        avgMoodValue: values.reduce((a, b) => a + b) / values.length,
        entryCount: values.length,
      ));
    }
  }
  return result;
}

List<DayEntryCount> _buildEntriesPerDay(Map<DateTime, int> entryDates, DateTime now,
    {int days = 14}) {
  final result = <DayEntryCount>[];
  for (int i = days - 1; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    final key = DateTime(date.year, date.month, date.day);
    result.add(DayEntryCount(date: key, count: entryDates[key] ?? 0));
  }
  return result;
}

int _weekNumber(DateTime d) {
  final jan1 = DateTime(d.year, 1, 1);
  return ((d.difference(jan1).inDays + jan1.weekday - 1) / 7).floor();
}

DateTime _dateFromWeek(int wn) {
  return DateTime(DateTime.now().year, 1, 1).add(Duration(days: 7 * wn));
}
