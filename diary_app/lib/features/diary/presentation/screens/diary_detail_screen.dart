import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/diary_entry.dart';
import '../providers/diary_provider.dart';
import 'editor_screen.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/theme/app_theme.dart';

class DiaryDetailScreen extends ConsumerWidget {
  final DiaryEntry entry;
  const DiaryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final images = entry.imagePaths.where((p) => File(p).existsSync()).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'edit') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditorScreen(existingEntry: entry)),
                );
                ref.read(diaryNotifierProvider.notifier).loadEntries();
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete entry?'),
                    content: Text('Delete "${entry.title}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  ref.read(diaryNotifierProvider.notifier).deleteEntry(entry.id);
                  Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: ListTile(
                leading: Icon(Icons.edit_outlined), title: Text('Edit'),
                contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
              )),
              const PopupMenuItem(value: 'delete', child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
              )),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.moodColor(entry.mood.name).withValues(alpha: 0.1),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.moodColor(entry.mood.name).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_moodIcon(entry.mood), size: 18,
                            color: AppColors.moodColor(entry.mood.name)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormatter.instance.formatFull(entry.createdAt),
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          Text(DateFormatter.instance.formatTime(entry.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      const Spacer(),
                      if (entry.isFavorite)
                        const Icon(Icons.favorite, size: 20, color: Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(entry.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, height: 1.2)),
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: entry.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('#$t', style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(entry.content,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
            ),
            if (images.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Images (${images.length})',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildImageGrid(images, theme, context),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images, ThemeData theme, BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _showImageFullscreen(context, images[i]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(images[i]), fit: BoxFit.cover,
              cacheWidth: 400, cacheHeight: 400,
              errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, size: 32),
              )),
        ),
      ),
    );
  }

  void _showImageFullscreen(BuildContext context, String path) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImage(path: path)));
  }

  IconData _moodIcon(Mood m) => switch (m) {
    Mood.happy => Icons.emoji_emotions, Mood.sad => Icons.sentiment_dissatisfied,
    Mood.angry => Icons.mood_bad, Mood.calm => Icons.self_improvement,
    Mood.anxious => Icons.sentiment_neutral, Mood.neutral => Icons.sentiment_satisfied,
  };
}

class _FullScreenImage extends StatelessWidget {
  final String path;
  const _FullScreenImage({required this.path});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48)),
        ),
      ),
    );
  }
}
