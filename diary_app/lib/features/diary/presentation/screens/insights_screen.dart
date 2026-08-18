import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/diary_entry.dart';
import '../providers/analytics_provider.dart';
import '../../../../core/theme/app_theme.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: data.totalEntries == 0
          ? _buildEmpty(theme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatCards(data, theme),
                const SizedBox(height: 24),
                _buildMoodTrendChart(data, theme),
                const SizedBox(height: 24),
                _buildWritingFrequencyChart(data, theme),
                const SizedBox(height: 24),
                _buildMoodDistribution(data, theme),
                if (data.topTags.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildTopTags(data, theme),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined, size: 64,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No data yet',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Start writing to see your insights!',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildStatCards(AnalyticsData data, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.menu_book_rounded,
                label: 'Total Entries',
                value: '${data.totalEntries}',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'Day Streak',
                value: '${data.currentStreak}',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.today,
                label: 'Today',
                value: '${data.entriesToday}',
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.date_range,
                label: 'This Week',
                value: '${data.entriesThisWeek}',
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodTrendChart(AnalyticsData data, ThemeData theme) {
    if (data.moodTrend.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Write entries across multiple weeks to see your mood trend',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      );
    }

    final spots = data.moodTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.avgMoodValue);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Mood Trend',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Average mood over time',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.surfaceContainerHighest,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.moodTrend.length) {
                            return const SizedBox();
                          }
                          final date = data.moodTrend[idx].weekStart;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('M/d').format(date),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final labels = {
                            0: '😤', 1: '😢', 2: '😰',
                            3: '😐', 4: '😌', 5: '😊',
                          };
                          return Text(
                            labels[value.toInt()] ?? '',
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: -0.2,
                  maxY: 5.2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: theme.colorScheme.primary,
                            strokeWidth: 0,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((spot) {
                        final labels = ['Angry', 'Sad', 'Anxious',
                            'Neutral', 'Calm', 'Happy'];
                        final idx = spot.spotIndex;
                        final point = data.moodTrend[idx];
                        return LineTooltipItem(
                          '${DateFormat('MMM d').format(point.weekStart)}\n'
                          '${labels[spot.y.round()]} '
                          '(${point.entryCount} entries)',
                          TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWritingFrequencyChart(AnalyticsData data, ThemeData theme) {
    final maxCount = data.entriesPerDay
        .fold<int>(0, (max, e) => e.count > max ? e.count : max);
    final ceiling = maxCount < 3 ? 3 : maxCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Writing Frequency',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Entries per day — last 14 days',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.surfaceContainerHighest,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return Text('${value.toInt()}',
                                style: theme.textTheme.labelSmall);
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.entriesPerDay.length) {
                            return const SizedBox();
                          }
                          final day = data.entriesPerDay[idx].date;
                          final label = idx == 0 || idx == data.entriesPerDay.length - 1
                              ? DateFormat('M/d').format(day)
                              : day.weekday == DateTime.monday
                                  ? DateFormat('M/d').format(day)
                                  : '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(label,
                                style: theme.textTheme.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: ceiling.toDouble() + 0.5,
                  barGroups: data.entriesPerDay.asMap().entries.map((e) {
                    final isToday = _isToday(e.value.date);
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.count.toDouble(),
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.5),
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = data.entriesPerDay[group.x];
                        return BarTooltipItem(
                          '${DateFormat('MMM d').format(entry.date)}\n'
                          '${entry.count} entries',
                          TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodDistribution(AnalyticsData data, ThemeData theme) {
    final total = data.totalEntries;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mood Distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...Mood.values.map((mood) {
              final count = data.moodDistribution[mood] ?? 0;
              final fraction = total > 0 ? count / total : 0.0;
              final label = mood.name[0].toUpperCase() + mood.name.substring(1);
              final isMostCommon = mood == data.mostCommonMood;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$label${isMostCommon ? ' ★' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isMostCommon ? FontWeight.w600 : null,
                          ),
                        ),
                        Text('$count',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: AppColors.moodColor(mood.name),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTags(AnalyticsData data, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most Used Tags',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.topTags.map((tag) {
                final maxCount = data.topTags.first.count;
                final opacity = 0.4 + (0.6 * tag.count / maxCount);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tag.tag} (${tag.count})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
