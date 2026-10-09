import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// App-wide settings with persistence
///
/// Settings are stored in the app execution directory as app_settings.json
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      _saveSettings();
    }
  }

  void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  // ─── Persistence ─────────────────────────────────────────────

  static const String _settingsFile = 'app_settings.json';

  Future<void> loadSettings() async {
    try {
      final file = File(_settingsFile);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        final themeModeStr = json['themeMode'] as String?;
        if (themeModeStr == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (themeModeStr == 'system') {
          _themeMode = ThemeMode.system;
        } else {
          _themeMode = ThemeMode.light;
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final json = {
        'themeMode': _themeMode == ThemeMode.dark
            ? 'dark'
            : _themeMode == ThemeMode.system
                ? 'system'
                : 'light',
      };
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);
      final file = File(_settingsFile);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }
}
