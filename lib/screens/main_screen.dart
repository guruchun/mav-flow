import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart' show appVersion;
import '../models/app_settings.dart';
import '../models/mavlink_state.dart';
import '../models/update_info.dart';
import '../services/communication/communication_interface.dart';
import '../services/communication/serial_communication.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/receive_panel.dart';
import '../widgets/role_selector.dart';
import '../widgets/send_panel.dart';

/// MAV-Flow Main Screen
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          const Expanded(
            child: Row(
              children: [
                Expanded(child: ReceivePanel()),
                VerticalDivider(width: 1, thickness: 1),
                Expanded(child: SendPanel()),
              ],
            ),
          ),
          const MavlinkStatusBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.toolbarBackground,
        border: Border(
          bottom: BorderSide(color: theme.toolbarBorder),
        ),
      ),
      child: const Row(
        children: [
          RoleSelector(),
          SizedBox(width: 24),
          Expanded(child: SerialConfigPanelCompact()),
          SizedBox(width: 12),
          _SettingsButton(),
        ],
      ),
    );
  }
}

/// Serial Port Configuration Panel
class SerialConfigPanelCompact extends StatefulWidget {
  const SerialConfigPanelCompact({super.key});

  @override
  State<SerialConfigPanelCompact> createState() =>
      _SerialConfigPanelCompactState();
}

class _SerialConfigPanelCompactState extends State<SerialConfigPanelCompact> {
  String? _selectedPort;
  int _baudRate = 115200;
  bool _isPortFocused = false;
  bool _isBaudFocused = false;

  final List<int> _baudRates = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    921600
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final isConnected = state.isConnected;
        final isConnecting =
            state.connectionState == SerialConnectionState.connecting;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Port selection
            const Text('Port: '),
            const SizedBox(width: 4),
            Focus(
              onFocusChange: (focused) => setState(() => _isPortFocused = focused),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkDropdownFill : Colors.white,
                  border: Border.all(
                    color: _isPortFocused
                        ? (isDark ? AppTheme.darkDropdownFocusedBorder : Colors.blue)
                        : (isDark ? AppTheme.darkDropdownBorder : Colors.grey[400]!),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _selectedPort,
                  hint: Text(
                    'Select',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                  dropdownColor: isDark ? AppTheme.darkDropdownColor : null,
                  focusColor: Colors.transparent,
                  items: _getAvailablePorts()
                      .map((port) =>
                          DropdownMenuItem(value: port, child: Text(port)))
                      .toList(),
                  onChanged: isConnected
                      ? null
                      : (value) => setState(() => _selectedPort = value),
                  underline: const SizedBox.shrink(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.grey[400] : null,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Baud rate
            const Text('Baud: '),
            const SizedBox(width: 4),
            Focus(
              onFocusChange: (focused) => setState(() => _isBaudFocused = focused),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkDropdownFill : Colors.white,
                  border: Border.all(
                    color: _isBaudFocused
                        ? (isDark ? AppTheme.darkDropdownFocusedBorder : Colors.blue)
                        : (isDark ? AppTheme.darkDropdownBorder : Colors.grey[400]!),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<int>(
                  value: _baudRate,
                  dropdownColor: isDark ? AppTheme.darkDropdownColor : null,
                  focusColor: Colors.transparent,
                  items: _baudRates
                      .map((rate) =>
                          DropdownMenuItem(value: rate, child: Text('$rate')))
                      .toList(),
                  onChanged: isConnected
                      ? null
                      : (value) => setState(() => _baudRate = value ?? 115200),
                  underline: const SizedBox.shrink(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.grey[400] : null,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Connect/Disconnect button
            ElevatedButton.icon(
              icon: isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isConnected ? Icons.link_off : Icons.link),
              label: Text(isConnected ? 'Disconnect' : 'Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: isConnecting
                  ? null
                  : () => _handleConnectDisconnect(context, state),
            ),
          ],
        );
      },
    );
  }

  List<String> _getAvailablePorts() {
    try {
      return SerialCommunication.availablePorts();
    } catch (e) {
      return [];
    }
  }

  Future<void> _handleConnectDisconnect(
      BuildContext context, MavlinkState state) async {
    if (state.isConnected) {
      await state.disconnect();
    } else {
      if (_selectedPort == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a port')),
        );
        return;
      }

      try {
        await state.connect(SerialConfig(
          portName: _selectedPort!,
          baudRate: _baudRate,
        ));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Settings Button
class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
      },
    );
  }
}

/// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<MavlinkState, AppSettings>(
        builder: (context, state, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme selection
              Card(
                child: ListTile(
                  leading: Icon(
                    settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  ),
                  title: const Text('Theme'),
                  subtitle: Text(settings.isDarkMode ? 'Dark' : 'Light'),
                  trailing: Switch(
                    value: settings.isDarkMode,
                    onChanged: (value) {
                      settings.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Message spec conversion
              Card(
                child: ListTile(
                  leading: const Icon(Icons.transform),
                  title: const Text('Convert Message Spec'),
                  subtitle: const Text('Convert MAVLink XML to JSON'),
                  trailing: ElevatedButton(
                    onPressed: () => _convertSpec(context, state),
                    child: const Text('Convert'),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Reset statistics
              Card(
                child: ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset Statistics'),
                  subtitle: const Text('Reset RX/TX packet counters'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      state.resetStats();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Statistics reset')),
                      );
                    },
                    child: const Text('Reset'),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Check for updates
              const _UpdateCheckCard(),

              const SizedBox(height: 16),

              // About
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('MAV-Flow'),
                  subtitle: Text('MAVLink Message Transceiver\nVersion 1.0.0'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _convertSpec(BuildContext context, MavlinkState state) async {
    try {
      // XML 폴더 선택 대화상자 표시
      final directory = await getDirectoryPath(
        confirmButtonText: 'Select Folder',
      );

      if (directory == null) {
        return; // 사용자가 취소
      }

      // 진행 표시
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Scanning XML files...'),
            ],
          ),
        ),
      );

      // 선택한 폴더에서 모든 XML 파일 찾기
      final dir = Directory(directory);
      final xmlFiles = await dir
          .list(recursive: true)
          .where((entity) => 
              entity is File && 
              entity.path.toLowerCase().endsWith('.xml'))
          .cast<File>()
          .toList();

      if (xmlFiles.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No XML files found in the selected folder'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // XML 파일 경로 목록
      final xmlPaths = xmlFiles.map((f) => f.path).toList();

      // role_config.json 경로 (assets 폴더 내)
      final currentDir = Directory.current.path;
      final roleConfigPath = '$currentDir/assets/config/role_config.json';
      final outputJsonPath = '$currentDir/assets/mavlink/messages.json';

      // 변환 실행
      await state.convertMessageSpec(
        xmlPaths: xmlPaths,
        outputJsonPath: outputJsonPath,
        roleConfigPath: roleConfigPath,
      );

      // 진행 대화상자 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 성공 메시지
      if (context.mounted) {
        final fileCount = xmlFiles.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Converted $fileCount XML files → messages.json'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 진행 대화상자가 열려 있으면 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// MAVLink Status Bar
class MavlinkStatusBar extends StatelessWidget {
  const MavlinkStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final connectionColor = switch (state.connectionState) {
          SerialConnectionState.connected => Colors.green,
          SerialConnectionState.connecting => Colors.orange,
          SerialConnectionState.error => Colors.red,
          SerialConnectionState.disconnected => Colors.grey,
        };

        final connectionText = switch (state.connectionState) {
          SerialConnectionState.connected => 'Connected',
          SerialConnectionState.connecting => 'Connecting...',
          SerialConnectionState.error => 'Error',
          SerialConnectionState.disconnected => 'Disconnected',
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.statusBarBackground,
            border: Border(
              top: BorderSide(color: theme.toolbarBorder),
            ),
          ),
          child: Row(
            children: [
              // Connection status
              Icon(Icons.circle, size: 12, color: connectionColor),
              const SizedBox(width: 4),
              Text(connectionText),

              const SizedBox(width: 24),

              // RX statistics
              const Icon(Icons.download, size: 16),
              const SizedBox(width: 4),
              Text('RX: ${state.rxPacketCount}'),

              const SizedBox(width: 16),

              // TX statistics
              const Icon(Icons.upload, size: 16),
              const SizedBox(width: 4),
              Text('TX: ${state.txPacketCount}'),

              const SizedBox(width: 16),

              // CRC errors
              if (state.crcErrorCount > 0) ...[
                Icon(Icons.error, size: 16, color: Colors.red[700]),
                const SizedBox(width: 4),
                Text(
                  'CRC Errors: ${state.crcErrorCount}',
                  style: TextStyle(color: Colors.red[700]),
                ),
                const SizedBox(width: 16),
              ],

              // RX rate
              Text('${state.rxRate.toStringAsFixed(1)} Hz'),

              const Spacer(),

              // Current role
              Text(
                'Role: ${state.isRoleSelected ? state.currentRoleConfig.name : "None"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Update Check Card for Settings screen
class _UpdateCheckCard extends StatefulWidget {
  const _UpdateCheckCard();

  @override
  State<_UpdateCheckCard> createState() => _UpdateCheckCardState();
}

class _UpdateCheckCardState extends State<_UpdateCheckCard> {
  UpdateInfo? _updateInfo;
  bool _isChecking = false;
  String? _errorMessage;

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final result = await UpdateService.checkForUpdates(appVersion);
      if (mounted) {
        setState(() {
          _updateInfo = result;
          _isChecking = false;
          if (result == null) {
            _errorMessage = 'Unable to check for updates';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Network error: $e';
        });
      }
    }
  }

  Future<void> _openDownloadPage() async {
    if (_updateInfo?.downloadUrl != null) {
      final success = await UpdateService.openDownloadPage(_updateInfo!.downloadUrl);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open download page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSubtitle(ThemeData theme) {
    final List<InlineSpan> spans = [
      TextSpan(text: 'Current version: $appVersion'),
    ];

    if (_isChecking) {
      spans.add(const TextSpan(text: '\nChecking...'));
    } else if (_errorMessage != null) {
      spans.add(TextSpan(
        text: '\n$_errorMessage',
        style: const TextStyle(color: Colors.red),
      ));
    } else if (_updateInfo != null) {
      if (_updateInfo!.hasUpdate) {
        spans.add(TextSpan(
          text: '\nUpdate available: v${_updateInfo!.latestVersion}',
          style: const TextStyle(color: Colors.green),
        ));
      } else {
        spans.add(TextSpan(
          text: '\nUp to date',
          style: TextStyle(color: theme.secondaryTextColor),
        ));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildTrailing() {
    if (_isChecking) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_updateInfo?.hasUpdate == true) {
      return ElevatedButton(
        onPressed: _openDownloadPage,
        child: const Text('Download'),
      );
    }

    return OutlinedButton(
      onPressed: _checkForUpdates,
      child: const Text('Check'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.system_update),
        title: const Text('Check for Updates'),
        subtitle: _buildSubtitle(theme),
        trailing: _buildTrailing(),
      ),
    );
  }
}
