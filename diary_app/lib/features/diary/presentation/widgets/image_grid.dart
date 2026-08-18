import 'dart:io';
import 'package:flutter/material.dart';

class ImageGrid extends StatelessWidget {
  final List<String> imagePaths;
  final void Function(int index)? onTap;
  final void Function(int index)? onDelete;
  final VoidCallback? onAdd;
  final int maxImages;

  const ImageGrid({
    super.key,
    required this.imagePaths,
    this.onTap,
    this.onDelete,
    this.onAdd,
    this.maxImages = 9,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : 3;
    final tileSize = (screenWidth - 32 - (crossAxisCount - 1) * 6) ~/ crossAxisCount;
    final cacheDimension = (tileSize * MediaQuery.of(context).devicePixelRatio).round();

    final totalItems = (onAdd != null && imagePaths.length < maxImages)
        ? imagePaths.length + 1
        : imagePaths.length;

    if (totalItems == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No images yet', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (int i = 0; i < imagePaths.length; i++)
          _ImageTile(
            path: imagePaths[i],
            size: tileSize.toDouble(),
            cacheDimension: cacheDimension,
            onTap: onTap != null ? () => onTap!(i) : null,
            onDelete: onDelete != null ? () => onDelete!(i) : null,
          ),
        if (onAdd != null && imagePaths.length < maxImages)
          _AddImageTile(size: tileSize.toDouble(), onPressed: onAdd!),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String path;
  final double size;
  final int cacheDimension;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _ImageTile({
    required this.path,
    required this.size,
    required this.cacheDimension,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: cacheDimension,
              cacheHeight: cacheDimension,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, size: 28),
              ),
            ),
            if (onTap != null)
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            if (onDelete != null)
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final double size;
  final VoidCallback onPressed;

  const _AddImageTile({required this.size, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 28, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text('Add', style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
