import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/auto_send_config.dart';
import '../models/mavlink_state.dart';
import '../theme/app_theme.dart';

/// Auto Send List Widget
class AutoSendList extends StatelessWidget {
  const AutoSendList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final configs = state.autoSendManager.allConfigs;

        if (configs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: theme.tableRowOdd,
            child: const Center(
              child: Text('No auto-send messages'),
            ),
          );
        }

        return Container(
          color: theme.tableRowOdd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: theme.tableHeaderBackground,
                child: const Row(
                  children: [
                    SizedBox(
                        width: 40,
                        child: Text('ON',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text('Message',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text('Interval',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(
                        width: 60,
                        child: Text('Count',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  itemCount: configs.length,
                  itemBuilder: (context, index) {
                    final config = configs[index];
                    return _AutoSendRow(
                      config: config,
                      onToggle: () => state.toggleAutoSend(config.messageId),
                      onIntervalChanged: (ms) =>
                          state.setAutoSendInterval(config.messageId, ms),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AutoSendRow extends StatefulWidget {
  final AutoSendConfig config;
  final VoidCallback onToggle;
  final ValueChanged<int> onIntervalChanged;

  const _AutoSendRow({
    required this.config,
    required this.onToggle,
    required this.onIntervalChanged,
  });

  @override
  State<_AutoSendRow> createState() => _AutoSendRowState();
}

class _AutoSendRowState extends State<_AutoSendRow> {
  late TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();
    _intervalController =
        TextEditingController(text: widget.config.intervalMs.toString());
  }

  @override
  void didUpdateWidget(_AutoSendRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.intervalMs != widget.config.intervalMs) {
      _intervalController.text = widget.config.intervalMs.toString();
    }
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = widget.config;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.toolbarBorder),
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              value: config.enabled,
              onChanged: (_) => widget.onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),

          // Message name
          Expanded(
            flex: 2,
            child: Text(
              config.messageName,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    config.enabled ? FontWeight.bold : FontWeight.normal,
                color: config.enabled ? theme.primaryTextColor : theme.secondaryTextColor,
              ),
            ),
          ),

          // Interval input
          Expanded(
            flex: 2,
            child: TextField(
              controller: _intervalController,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(),
                suffixText: 'ms',
              ),
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (value) {
                final ms = int.tryParse(value);
                if (ms != null && ms >= AutoSendConfig.minIntervalMs) {
                  widget.onIntervalChanged(ms);
                } else {
                  _intervalController.text = config.intervalMs.toString();
                }
              },
            ),
          ),

          // Send count
          SizedBox(
            width: 60,
            child: Text(
              config.sendCount.toString(),
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Auto Send Control Bar
class AutoSendControlBar extends StatelessWidget {
  const AutoSendControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final enabledCount = state.autoSendManager.enabledConfigs.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: enabledCount > 0 ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                'Auto Send: $enabledCount',
                style: TextStyle(
                  fontSize: 12,
                  color: enabledCount > 0 ? Colors.green[400] : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              if (enabledCount > 0)
                TextButton(
                  onPressed: () {
                    state.stopAllAutoSend();
                  },
                  child: const Text('Stop All', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}
