import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'update_info.dart';
import '../services/update_service.dart';

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

  // ─── Update State ────────────────────────────────────────────

  UpdateInfo? _updateInfo;
  bool _isCheckingUpdate = false;
  bool _updateDismissed = false;

  /// 업데이트 정보 (null이면 아직 확인 안 됨)
  UpdateInfo? get updateInfo => _updateInfo;

  /// 업데이트 확인 중인지 여부
  bool get isCheckingUpdate => _isCheckingUpdate;

  /// 업데이트 알림이 닫혔는지 여부
  bool get updateDismissed => _updateDismissed;

  /// 업데이트가 가능한지 여부 (알림 표시용)
  bool get hasAvailableUpdate =>
      _updateInfo != null && _updateInfo!.hasUpdate && !_updateDismissed;

  /// 업데이트를 확인합니다.
  Future<void> checkForUpdates(String currentVersion) async {
    if (_isCheckingUpdate) return;

    _isCheckingUpdate = true;
    notifyListeners();

    try {
      _updateInfo = await UpdateService.checkForUpdates(currentVersion);
      _updateDismissed = false;
    } finally {
      _isCheckingUpdate = false;
      notifyListeners();
    }
  }

  /// 업데이트 알림을 닫습니다.
  void dismissUpdate() {
    _updateDismissed = true;
    notifyListeners();
  }

  /// 업데이트 상태를 초기화합니다.
  void resetUpdateState() {
    _updateInfo = null;
    _updateDismissed = false;
    notifyListeners();
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
