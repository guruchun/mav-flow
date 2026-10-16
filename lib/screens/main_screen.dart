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
          // Update notification banner
          const _UpdateBanner(),
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

/// Update notification banner
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        if (!settings.hasAvailableUpdate) {
          return const SizedBox.shrink();
        }

        final updateInfo = settings.updateInfo!;

        return MaterialBanner(
          backgroundColor: Colors.blue[700],
          contentTextStyle: const TextStyle(color: Colors.white),
          content: Text(
            'New version available: v${updateInfo.latestVersion} (Current: v${updateInfo.currentVersion})',
          ),
          leading: const Icon(Icons.system_update, color: Colors.white),
          actions: [
            TextButton(
              onPressed: () => settings.dismissUpdate(),
              child: const Text('Later', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => _showUpdateDialog(context, updateInfo),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => _UpdateDialog(updateInfo: updateInfo),
    );
  }
}

/// Update dialog
class _UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateDialog({required this.updateInfo});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      // Download
      final zipPath = await UpdateService.downloadUpdate(
        widget.updateInfo,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (zipPath == null) {
        setState(() {
          _errorMessage = 'Download failed.';
          _isDownloading = false;
        });
        return;
      }

      // Install (requires app restart)
      if (!mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Install Update'),
          content: const Text(
            'The app needs to restart to install the update.\nDo you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restart'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await UpdateService.installUpdate(zipPath);
        if (success) {
          // Exit app
          exit(0);
        } else {
          setState(() {
            _errorMessage = 'Installation failed.';
            _isDownloading = false;
          });
        }
      } else {
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update v${widget.updateInfo.latestVersion}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current version: v${widget.updateInfo.currentVersion}'),
            const SizedBox(height: 8),
            Text('New version: v${widget.updateInfo.latestVersion}'),
            const SizedBox(height: 16),
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.releaseNotes,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isDownloading) ...[
              const Text('Downloading...'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 4),
              Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
            ],
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.updateInfo.zipDownloadUrl != null)
          ElevatedButton(
            onPressed: _isDownloading ? null : _downloadAndInstall,
            child: const Text('Download & Install'),
          )
        else
          ElevatedButton(
            onPressed: _isDownloading
                ? null
                : () => UpdateService.openDownloadPage(widget.updateInfo.downloadUrl),
            child: const Text('Open Download Page'),
          ),
      ],
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
      // Show XML folder selection dialog
      final directory = await getDirectoryPath(
        confirmButtonText: 'Select Folder',
      );

      if (directory == null) {
        return; // User cancelled
      }

      // Show progress indicator
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

      // Find all XML files in selected folder
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

      // XML file path list
      final xmlPaths = xmlFiles.map((f) => f.path).toList();

      // role_config.json path (in assets folder)
      final currentDir = Directory.current.path;
      final roleConfigPath = '$currentDir/assets/config/role_config.json';
      final outputJsonPath = '$currentDir/assets/mavlink/messages.json';

      // Execute conversion
      await state.convertMessageSpec(
        xmlPaths: xmlPaths,
        outputJsonPath: outputJsonPath,
        roleConfigPath: roleConfigPath,
      );

      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Success message
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
      // Close progress dialog if open
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
  String? _errorMessage;

  Future<void> _checkForUpdates() async {
    final settings = context.read<AppSettings>();
    
    setState(() {
      _errorMessage = null;
    });

    await settings.checkForUpdates(appVersion);
    
    if (mounted && settings.updateInfo == null) {
      setState(() {
        _errorMessage = 'Unable to check for updates';
      });
    }
  }

  void _showUpdateDialog() {
    final settings = context.read<AppSettings>();
    if (settings.updateInfo != null) {
      showDialog(
        context: context,
        builder: (context) => _UpdateDialog(updateInfo: settings.updateInfo!),
      );
    }
  }

  Widget _buildSubtitle(ThemeData theme, AppSettings settings) {
    final List<InlineSpan> spans = [
      TextSpan(text: 'Current version: $appVersion'),
    ];

    if (settings.isCheckingUpdate) {
      spans.add(const TextSpan(text: '\nChecking...'));
    } else if (_errorMessage != null) {
      spans.add(TextSpan(
        text: '\n$_errorMessage',
        style: const TextStyle(color: Colors.red),
      ));
    } else if (settings.updateInfo != null) {
      if (settings.updateInfo!.hasUpdate) {
        spans.add(TextSpan(
          text: '\nUpdate available: v${settings.updateInfo!.latestVersion}',
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

  Widget _buildTrailing(AppSettings settings) {
    if (settings.isCheckingUpdate) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (settings.updateInfo?.hasUpdate == true) {
      return ElevatedButton(
        onPressed: _showUpdateDialog,
        child: const Text('Update'),
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

    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Check for Updates'),
            subtitle: _buildSubtitle(theme, settings),
            trailing: _buildTrailing(settings),
          ),
        );
      },
    );
  }
}
