import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/diary_entry.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/theme/app_theme.dart';

class DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const DiaryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImages = entry.imagePaths.isNotEmpty;
    final images = entry.imagePaths.where((p) => File(p).existsSync()).take(3).toList();

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => await _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.error,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          child: hasImages && images.isNotEmpty
              ? _buildWithImages(theme, images, context)
              : _buildTextOnly(theme, context),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Delete "${entry.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;
  }

  Widget _buildWithImages(ThemeData theme, List<String> images, BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _buildContent(theme, context),
            ),
          ),
          _buildImageStrip(theme, images),
        ],
      ),
    );
  }

  Widget _buildTextOnly(ThemeData theme, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: _buildContent(theme, context),
    );
  }

  Widget _buildContent(ThemeData theme, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.moodColor(entry.mood.name).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_moodIcon(entry.mood), size: 16,
                  color: AppColors.moodColor(entry.mood.name)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(entry.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (entry.isFavorite) const Icon(Icons.favorite, size: 14, color: Colors.red),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.onSurfaceVariant),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') _confirmDelete(context).then((confirmed) {
                  if (confirmed) onDelete();
                });
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(
                  leading: Icon(Icons.edit_outlined, size: 20), title: Text('Edit'),
                  contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
                )),
                const PopupMenuItem(value: 'delete', child: ListTile(
                  leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)),
                  contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
                )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(entry.content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.4,
            ),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(DateFormatter.instance.formatRelative(entry.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            if (entry.imagePaths.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('+${entry.imagePaths.length - 3}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageStrip(ThemeData theme, List<String> images) {
    final imageCount = images.length;
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: imageCount == 1
          ? ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              child: Image.file(File(images[0]), fit: BoxFit.cover, width: 100,
                  cacheWidth: 600, cacheHeight: 600,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
            )
          : Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
                    child: Image.file(File(images[0]), fit: BoxFit.cover, width: 100,
                        cacheWidth: 600, cacheHeight: 300,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: ClipRRect(
                    borderRadius: imageCount == 2
                        ? const BorderRadius.only(bottomRight: Radius.circular(16))
                        : const BorderRadius.only(topRight: Radius.circular(16)),
                    child: Image.file(File(images[1]), fit: BoxFit.cover, width: 100,
                        cacheWidth: 600, cacheHeight: 300,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                  ),
                ),
                if (imageCount >= 3) ...[
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                      child: Stack(
                        children: [
                          Image.file(File(images[2]), fit: BoxFit.cover, width: 100,
                              cacheWidth: 600, cacheHeight: 300,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                          if (entry.imagePaths.length > 3)
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: const BorderRadius.only(
                                      bottomRight: Radius.circular(16)),
                                ),
                                child: Text('+${entry.imagePaths.length - 3}',
                                    style: const TextStyle(color: Colors.white, fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  IconData _moodIcon(Mood m) => switch (m) {
    Mood.happy => Icons.emoji_emotions, Mood.sad => Icons.sentiment_dissatisfied,
    Mood.angry => Icons.mood_bad, Mood.calm => Icons.self_improvement,
    Mood.anxious => Icons.sentiment_neutral, Mood.neutral => Icons.sentiment_satisfied,
  };
}
