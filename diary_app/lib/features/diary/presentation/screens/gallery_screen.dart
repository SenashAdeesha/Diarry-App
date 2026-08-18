import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../widgets/image_grid.dart';
import 'diary_detail_screen.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  List<String> _allImagePaths(List<DiaryEntry> entries) {
    final paths = <String>[];
    for (final entry in entries) {
      for (final path in entry.imagePaths) {
        if (!paths.contains(path)) paths.add(path);
      }
    }
    return paths;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diaryNotifierProvider);
    final images = _allImagePaths(state.entries);

    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery (${images.length})'),
      ),
      body: images.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No images yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Images from your diary entries will appear here',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: ImageGrid(
                imagePaths: images,
                onTap: (index) {
                  // Find entry containing this image and open detail
                  for (final entry in state.entries) {
                    if (entry.imagePaths.contains(images[index])) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiaryDetailScreen(entry: entry),
                        ),
                      );
                      return;
                    }
                  }
                },
              ),
            ),
    );
  }
}
