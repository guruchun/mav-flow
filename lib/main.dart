import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/monitor_state.dart';
import 'screens/main_screen.dart';

const String appVersion = '1.0.0';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => MonitorState(),
      child: const Mg3CommApp(),
    ),
  );
}

class Mg3CommApp extends StatelessWidget {
  const Mg3CommApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCU-MG3 Serial Monitor v$appVersion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
