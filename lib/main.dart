import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'models/mavlink_state.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

/// App version (loaded from package_info_plus at runtime)
String appVersion = '1.0.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load version info from pubspec.yaml
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;
  } catch (e) {
    debugPrint('Failed to load package info: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (_) => MavlinkState()),
      ],
      child: const MavFlowApp(),
    ),
  );
}

class MavFlowApp extends StatefulWidget {
  const MavFlowApp({super.key});

  @override
  State<MavFlowApp> createState() => _MavFlowAppState();
}

class _MavFlowAppState extends State<MavFlowApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    
    // Load app settings (theme, etc.)
    final settings = context.read<AppSettings>();
    await settings.loadSettings();

    if (!mounted) return;
    final state = context.read<MavlinkState>();

    // 1. Load message spec
    try {
      await state.loadSpec('assets/mavlink/messages.json');
    } catch (e) {
      debugPrint('Failed to load message spec: $e');
    }

    // 2. Load role configs
    try {
      await state.loadRoleConfigs('assets/config/role_config.json');
    } catch (e) {
      debugPrint('Failed to load role config: $e');
    }

    // 3. Check for updates (background, non-blocking)
    _checkForUpdatesInBackground(settings);
  }

  /// Check for updates in background
  void _checkForUpdatesInBackground(AppSettings settings) {
    // Delay check to avoid network load immediately after app start
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        settings.checkForUpdates(appVersion);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'MAV-Flow v$appVersion',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}
