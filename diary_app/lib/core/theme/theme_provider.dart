import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme_config.dart';
import 'app_theme.dart';

final themePreferencesProvider =
    NotifierProvider<ThemeNotifier, ThemePreferences>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemePreferences> {
  final _storage = const FlutterSecureStorage();
  static const _prefsKey = 'theme_preferences';

  @override
  ThemePreferences build() {
    _load();
    return const ThemePreferences();
  }

  Future<void> _load() async {
    final raw = await _storage.read(key: _prefsKey);
    if (raw == null) return;
    try {
      final map = raw.split('&').fold<Map<String, String?>>({}, (m, pair) {
        final parts = pair.split('=');
        if (parts.length == 2) m[parts[0]] = parts[1];
        return m;
      });
      state = ThemePreferences.fromMap(map);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final str = state.toMap().entries.map((e) => '${e.key}=${e.value}').join('&');
    await _storage.write(key: _prefsKey, value: str);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _persist();
  }

  Future<void> setAccentColor(ColorSeed color) async {
    state = state.copyWith(accentColor: color);
    await _persist();
  }

  Future<void> setFontSize(FontSizePreset size) async {
    state = state.copyWith(fontSize: size);
    await _persist();
  }

  Future<void> setSpacing(SpacingPreset spacing) async {
    state = state.copyWith(spacing: spacing);
    await _persist();
  }
}

final themeDataProvider = Provider<ThemeData>((ref) {
  final prefs = ref.watch(themePreferencesProvider);
  final light = AppTheme.fromPrefs(prefs, Brightness.light);
  final dark = AppTheme.fromPrefs(prefs, Brightness.dark);
  return prefs.mode == ThemeMode.dark ? dark : light;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themePreferencesProvider).mode;
});
