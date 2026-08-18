import '../domain_exceptions.dart';

enum Mood { happy, sad, angry, calm, anxious, neutral }

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Mood mood;
  final List<String> tags;
  final bool isFavorite;
  final List<String> imagePaths;

  const DiaryEntry._({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.mood,
    required this.tags,
    required this.isFavorite,
    required this.imagePaths,
  });

  factory DiaryEntry({
    required String id,
    required String title,
    required String content,
    DateTime? createdAt,
    DateTime? updatedAt,
    Mood mood = Mood.neutral,
    List<String>? tags,
    bool isFavorite = false,
    List<String>? imagePaths,
  }) {
    if (title.trim().isEmpty) {
      throw const ValidationException('Title must not be empty');
    }
    if (content.trim().isEmpty) {
      throw const ValidationException('Content must not be empty');
    }
    final now = DateTime.now();
    return DiaryEntry._(
      id: id,
      title: title.trim(),
      content: content.trim(),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      mood: mood,
      tags: List.unmodifiable(tags ?? const []),
      isFavorite: isFavorite,
      imagePaths: List.unmodifiable(imagePaths ?? const []),
    );
  }

  factory DiaryEntry.hydrate({
    required String id,
    required String title,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    required Mood mood,
    required List<String> tags,
    required bool isFavorite,
    required List<String> imagePaths,
  }) {
    return DiaryEntry._(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      mood: mood,
      tags: List.unmodifiable(tags),
      isFavorite: isFavorite,
      imagePaths: List.unmodifiable(imagePaths),
    );
  }

  DiaryEntry copyWith({
    String? title,
    String? content,
    Mood? mood,
    List<String>? tags,
    bool? isFavorite,
    List<String>? imagePaths,
  }) {
    return DiaryEntry._(
      id: id,
      title: (title != null && title.trim().isEmpty)
          ? throw const ValidationException('Title must not be empty')
          : (title?.trim() ?? this.title),
      content: (content != null && content.trim().isEmpty)
          ? throw const ValidationException('Content must not be empty')
          : (content?.trim() ?? this.content),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      mood: mood ?? this.mood,
      tags: tags != null ? List.unmodifiable(tags) : this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      imagePaths: imagePaths != null ? List.unmodifiable(imagePaths) : this.imagePaths,
    );
  }

  DiaryEntry toggleFavorite() {
    return DiaryEntry._(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      mood: mood,
      tags: tags,
      isFavorite: !isFavorite,
      imagePaths: imagePaths,
    );
  }

  DiaryEntry addTag(String tag) {
    if (tags.contains(tag)) return this;
    return DiaryEntry._(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      mood: mood,
      tags: List.unmodifiable([...tags, tag]),
      isFavorite: isFavorite,
      imagePaths: imagePaths,
    );
  }

  DiaryEntry removeTag(String tag) {
    if (!tags.contains(tag)) return this;
    return DiaryEntry._(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      mood: mood,
      tags: List.unmodifiable(tags.where((t) => t != tag)),
      isFavorite: isFavorite,
      imagePaths: imagePaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DiaryEntry(id: $id, title: $title, mood: ${mood.name}, images: ${imagePaths.length})';
}
