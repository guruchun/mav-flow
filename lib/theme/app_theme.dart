import 'package:flutter/material.dart';

/// App theme definitions
class AppTheme {
  AppTheme._();

  /// Light theme
  static ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  /// Dark theme (blue-based, GitHub style)
  static ThemeData dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF161B22),
      surfaceContainerHighest: const Color(0xFF21262D),
      surfaceContainerLow: const Color(0xFF30363D),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0D1117),
    cardColor: const Color(0xFF161B22),
    dividerColor: const Color(0xFF30363D),
    // Card theme - dark surface color
    cardTheme: const CardThemeData(
      color: Color(0xFF161B22),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: Color(0xFF30363D)),
      ),
    ),
    // ListTile theme for better text visibility
    listTileTheme: const ListTileThemeData(
      textColor: Color(0xFFE6EDF3),
      iconColor: Color(0xFF8B949E),
    ),
    // ElevatedButton theme for better visibility
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
      ),
    ),
    // Input decoration theme - visible borders
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: const Color(0xFF30363D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: const Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue[400]!),
      ),
      filled: true,
      fillColor: const Color(0xFF161B22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    // Dropdown menu theme - lighter background for better visibility
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFF3D444D)),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF3D444D),
      surfaceTintColor: Colors.transparent,
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFF3D444D)),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
  );

  /// Dropdown color for dark theme (use with DropdownButtonFormField.dropdownColor)
  static const Color darkDropdownColor = Color(0xFF2D333B);
  
  /// Dropdown fill color (background when not expanded)
  static const Color darkDropdownFill = Color(0xFF161B22);
  
  /// Dropdown border color
  static const Color darkDropdownBorder = Color(0xFF30363D);
  
  /// Dropdown focused border color
  static const Color darkDropdownFocusedBorder = Color(0xFF58A6FF);
}

/// Extension to get theme-aware colors for panels
extension AppThemeColors on ThemeData {
  /// Toolbar/header background
  Color get toolbarBackground => brightness == Brightness.dark
      ? const Color(0xFF161B22)
      : Colors.grey[100]!;

  /// Toolbar border
  Color get toolbarBorder => brightness == Brightness.dark
      ? const Color(0xFF30363D)
      : Colors.grey[300]!;

  /// Status bar background
  Color get statusBarBackground => brightness == Brightness.dark
      ? const Color(0xFF161B22)
      : Colors.grey[200]!;

  /// Panel header background (RX - blue tint)
  Color get rxPanelHeader => brightness == Brightness.dark
      ? const Color(0xFF1A2332)
      : Colors.blue[50]!;

  /// Panel header background (TX - orange tint)
  Color get txPanelHeader => brightness == Brightness.dark
      ? const Color(0xFF2D2418)
      : Colors.orange[50]!;

  /// Table header background
  Color get tableHeaderBackground => brightness == Brightness.dark
      ? const Color(0xFF21262D)
      : Colors.grey[200]!;

  /// Table row even background
  Color get tableRowEven => brightness == Brightness.dark
      ? const Color(0xFF0D1117)
      : Colors.white;

  /// Table row odd background
  Color get tableRowOdd => brightness == Brightness.dark
      ? const Color(0xFF161B22)
      : Colors.grey[50]!;

  /// Secondary text color
  Color get secondaryTextColor => brightness == Brightness.dark
      ? Colors.grey[400]!
      : Colors.grey[600]!;

  /// Primary text color for values
  Color get primaryTextColor => brightness == Brightness.dark
      ? Colors.grey[200]!
      : Colors.black;
}
