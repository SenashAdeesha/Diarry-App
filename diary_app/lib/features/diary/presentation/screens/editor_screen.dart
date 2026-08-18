import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../widgets/mood_selector.dart';
import '../widgets/image_grid.dart';
import '../../../../core/services/image_service.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/constants/app_constants.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final DiaryEntry? existingEntry;

  const EditorScreen({super.key, this.existingEntry});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  Mood _selectedMood = Mood.neutral;
  List<String> _imagePaths = [];
  final _removedImagePaths = <String>[];
  bool _isBusy = false;

  bool get isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEntry?.title);
    _contentController = TextEditingController(text: widget.existingEntry?.content);
    if (widget.existingEntry != null) {
      _selectedMood = widget.existingEntry!.mood;
      _imagePaths = List.from(widget.existingEntry!.imagePaths);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final service = ImageService.instance;
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    String? path;
    setState(() => _isBusy = true);

    try {
      path = source == 'camera'
          ? await service.captureFromCamera()
          : await service.pickFromGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }

    if (path != null && mounted) {
      setState(() => _imagePaths.add(path!));
    }
  }

  void _removeImage(int index) {
    final path = _imagePaths[index];
    _removedImagePaths.add(path);
    setState(() => _imagePaths.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);

    final now = DateTime.now();
    final notifier = ref.read(diaryNotifierProvider.notifier);

    try {
      if (isEditing) {
        final updated = widget.existingEntry!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          mood: _selectedMood,
          imagePaths: _imagePaths,
        );
        await notifier.updateEntry(updated);
      } else {
        final entry = DiaryEntry(
          id: IdGenerator.instance.newId(),
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          createdAt: now,
          updatedAt: now,
          mood: _selectedMood,
          tags: [],
          imagePaths: _imagePaths,
        );
        await notifier.addEntry(entry);
      }

      await ImageService.instance.deleteImages(_removedImagePaths.toList(growable: false));

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
        actions: [
          TextButton(
            onPressed: _isBusy ? null : _save,
            child: _isBusy
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What is the title of your entry?',
                ),
                maxLength: AppConstants.maxTitleLength,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              MoodSelector(
                selectedMood: _selectedMood,
                onChanged: (mood) => setState(() => _selectedMood = mood),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _contentController,
                maxLines: null,
                minLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Write your thoughts...',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please write something';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Images', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  if (_imagePaths.isNotEmpty)
                    Text('${_imagePaths.length}/9',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 12),
              ImageGrid(
                imagePaths: _imagePaths,
                onDelete: _removeImage,
                onAdd: _imagePaths.length < 9 ? _pickImage : null,
                onTap: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
