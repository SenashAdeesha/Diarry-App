import 'package:flutter/material.dart';
import '../../domain/entities/diary_entry.dart';
import '../../../../core/theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  final Mood selectedMood;
  final ValueChanged<Mood> onChanged;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onChanged,
  });

  static const _moodData = {
    Mood.happy: ('Happy', Icons.emoji_emotions, AppColors.happy),
    Mood.sad: ('Sad', Icons.sentiment_dissatisfied, AppColors.sad),
    Mood.angry: ('Angry', Icons.mood_bad, AppColors.angry),
    Mood.calm: ('Calm', Icons.self_improvement, AppColors.calm),
    Mood.anxious: ('Anxious', Icons.sentiment_neutral, AppColors.anxious),
    Mood.neutral: ('Okay', Icons.sentiment_satisfied, AppColors.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How are you feeling?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Mood.values.map((mood) {
            final data = _moodData[mood]!;
            final isSelected = mood == selectedMood;
            return FilterChip(
              selected: isSelected,
              onSelected: (_) => onChanged(mood),
              avatar: Icon(data.$2, size: 18, color: isSelected ? Colors.white : data.$3),
              label: Text(data.$1),
              selectedColor: data.$3,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
