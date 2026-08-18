import 'package:flutter/material.dart';

enum ColorSeed {
  indigo(Color(0xFF6366F1), 'Indigo'),
  teal(Color(0xFF0D9488), 'Teal'),
  rose(Color(0xFFE11D48), 'Rose'),
  amber(Color(0xFFD97706), 'Amber'),
  emerald(Color(0xFF059669), 'Emerald'),
  violet(Color(0xFF7C3AED), 'Violet'),
  sky(Color(0xFF0284C7), 'Sky'),
  orange(Color(0xFFEA580C), 'Orange');

  final Color color;
  final String label;
  const ColorSeed(this.color, this.label);
}

enum FontSizePreset {
  small(14.0, 'Small'),
  normal(16.0, 'Normal'),
  large(18.0, 'Large');

  final double size;
  final String label;
  const FontSizePreset(this.size, this.label);
}

enum SpacingPreset {
  compact(1.2, 'Compact'),
  normal(1.5, 'Normal'),
  comfortable(1.8, 'Comfortable');

  final double lineHeight;
  final String label;
  const SpacingPreset(this.lineHeight, this.label);
}

class ThemePreferences {
  final ThemeMode mode;
  final ColorSeed accentColor;
  final FontSizePreset fontSize;
  final SpacingPreset spacing;

  const ThemePreferences({
    this.mode = ThemeMode.system,
    this.accentColor = ColorSeed.indigo,
    this.fontSize = FontSizePreset.normal,
    this.spacing = SpacingPreset.normal,
  });

  ThemePreferences copyWith({
    ThemeMode? mode,
    ColorSeed? accentColor,
    FontSizePreset? fontSize,
    SpacingPreset? spacing,
  }) {
    return ThemePreferences(
      mode: mode ?? this.mode,
      accentColor: accentColor ?? this.accentColor,
      fontSize: fontSize ?? this.fontSize,
      spacing: spacing ?? this.spacing,
    );
  }

  Map<String, String> toMap() => {
        'mode': mode.name,
        'accentColor': accentColor.name,
        'fontSize': fontSize.name,
        'spacing': spacing.name,
      };

  factory ThemePreferences.fromMap(Map<String, String?> map) {
    return ThemePreferences(
      mode: ThemeMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => ThemeMode.system,
      ),
      accentColor: ColorSeed.values.firstWhere(
        (e) => e.name == map['accentColor'],
        orElse: () => ColorSeed.indigo,
      ),
      fontSize: FontSizePreset.values.firstWhere(
        (e) => e.name == map['fontSize'],
        orElse: () => FontSizePreset.normal,
      ),
      spacing: SpacingPreset.values.firstWhere(
        (e) => e.name == map['spacing'],
        orElse: () => SpacingPreset.normal,
      ),
    );
  }
}
