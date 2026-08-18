import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/entities/diary_entry.dart';

part 'diary_entry_model.g.dart';

@HiveType(typeId: 0)
class DiaryEntryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final String mood;

  @HiveField(6)
  final List<String> tags;

  @HiveField(7)
  final bool isFavorite;

  @HiveField(8)
  final List<String> imagePaths;

  DiaryEntryModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood = 'neutral',
    this.tags = const [],
    this.isFavorite = false,
    this.imagePaths = const [],
  });

  DiaryEntryModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mood,
    List<String>? tags,
    bool? isFavorite,
    List<String>? imagePaths,
  }) {
    return DiaryEntryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  factory DiaryEntryModel.fromEntity(DiaryEntry entry) {
    return DiaryEntryModel(
      id: entry.id,
      title: entry.title,
      content: entry.content,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      mood: entry.mood.name,
      tags: List.from(entry.tags),
      isFavorite: entry.isFavorite,
      imagePaths: List.from(entry.imagePaths),
    );
  }

  DiaryEntry toEntity() {
    final moodEnum = Mood.values.firstWhere(
      (m) => m.name == mood,
      orElse: () => Mood.neutral,
    );
    return DiaryEntry.hydrate(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      mood: moodEnum,
      tags: List.from(tags),
      isFavorite: isFavorite,
      imagePaths: List.from(imagePaths),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'mood': mood,
        'tags': tags,
        'is_favorite': isFavorite,
        'image_paths': imagePaths,
      };

  factory DiaryEntryModel.fromJson(Map<String, dynamic> json) {
    return DiaryEntryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      mood: json['mood'] as String? ?? 'neutral',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isFavorite: json['is_favorite'] as bool? ?? false,
      imagePaths: (json['image_paths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  String toJsonString() => jsonEncode(toJson());
}
