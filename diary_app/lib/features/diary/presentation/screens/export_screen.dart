import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/theme/app_theme.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final DiaryEntry? initialEntry;

  const ExportScreen({super.key, this.initialEntry});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final _selectedIds = <String>{};
  final _previewKey = GlobalKey();
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _isExporting = false;

  List<DiaryEntry> get _allEntries =>
      ref.watch(diaryNotifierProvider).entries;

  List<DiaryEntry> get _selectedEntries =>
      _allEntries.where((e) => _selectedIds.contains(e.id)).toList();

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      _selectedIds.add(widget.initialEntry!.id);
    }
  }

  Future<void> _export() async {
    final entries = _selectedEntries;
    if (entries.isEmpty) return;

    setState(() => _isExporting = true);

    try {
      final svc = ExportService.instance;
      switch (_selectedFormat) {
        case ExportFormat.pdf:
          await svc.exportAsPdf(entries, context);
        case ExportFormat.text:
          await svc.exportAsText(entries, context);
        case ExportFormat.image:
          await svc.exportAsImage(_previewKey, context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntries = _allEntries;
    final selected = _selectedEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text('Export (${selected.length})'),
        actions: [
          if (_selectedEntries.isNotEmpty)
            TextButton(
              onPressed: _isExporting ? null : _export,
              child: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Export'),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFormatSelector(theme),
              const Divider(height: 1),
              Expanded(
                child: allEntries.isEmpty
                    ? Center(
                        child: Text('No entries to export',
                            style: theme.textTheme.bodyMedium))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allEntries.length,
                        itemBuilder: (_, i) =>
                            _buildEntryTile(allEntries[i], theme),
                      ),
              ),
            ],
          ),
          if (_selectedFormat == ExportFormat.image && selected.isNotEmpty)
            Positioned(
              left: -10000,
              top: 0,
              child: Opacity(
                opacity: 0,
                child: RepaintBoundary(
                  key: _previewKey,
                  child: _buildImageCard(selected.first, theme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text('Format:', style: theme.textTheme.titleSmall),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<ExportFormat>(
              segments: const [
                ButtonSegment(
                    value: ExportFormat.pdf,
                    icon: Icon(Icons.picture_as_pdf),
                    label: Text('PDF')),
                ButtonSegment(
                    value: ExportFormat.text,
                    icon: Icon(Icons.text_snippet),
                    label: Text('Text')),
                ButtonSegment(
                    value: ExportFormat.image,
                    icon: Icon(Icons.image),
                    label: Text('Image')),
              ],
              selected: {_selectedFormat},
              onSelectionChanged: (s) =>
                  setState(() => _selectedFormat = s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(DiaryEntry entry, ThemeData theme) {
    final selected = _selectedIds.contains(entry.id);
    final dateStr = DateFormat('MMM d, yyyy').format(entry.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _selectedIds.remove(entry.id);
            } else {
              _selectedIds.add(entry.id);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(entry.id);
                    } else {
                      _selectedIds.add(entry.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.moodColor(entry.mood.name)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _moodIcon(entry.mood),
                  size: 16,
                  color: AppColors.moodColor(entry.mood.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(dateStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (entry.imagePaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.image, size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(DiaryEntry entry, ThemeData theme) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.moodColor(entry.mood.name),
            AppColors.moodColor(entry.mood.name).withValues(alpha: 0.6),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_moodIcon(entry.mood), size: 28,
                  color: Colors.white),
              const SizedBox(width: 8),
              Text(DateFormat('MMM d, yyyy').format(entry.createdAt),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Text(entry.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              )),
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(entry.content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.6,
              ),
              maxLines: 15,
              overflow: TextOverflow.ellipsis),
          const Spacer(),
          if (entry.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 6,
                children: entry.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('#$t',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ))
                    .toList(),
              ),
            ),
        ],
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
