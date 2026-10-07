import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitor_state.dart';

/// 시리얼 포트 설정 패널.
///
/// Python _create_serial_config_panel()에 대응한다.
class SerialConfigPanel extends StatefulWidget {
  const SerialConfigPanel({super.key});

  @override
  State<SerialConfigPanel> createState() => _SerialConfigPanelState();
}

class _SerialConfigPanelState extends State<SerialConfigPanel> {
  String? _selectedPort;
  String _baudrate = '115200';
  String _parity = 'None';
  String _databits = '8';
  String _stopbits = '1';
  String _flowcontrol = 'None';

  static const _baudrates = ['9600', '19200', '38400', '57600', '115200'];
  static const _parities = ['None', 'Even', 'Odd'];
  static const _databitsOpts = ['7', '8'];
  static const _stopbitsOpts = ['1', '2'];
  static const _flowOpts = ['None', 'RTS/CTS', 'XON/XOFF'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MonitorState>();
    final ports = state.availablePorts;
    final isConnected = state.isConnected;

    // 포트 목록 갱신 시 선택값 보정
    if (_selectedPort != null && !ports.contains(_selectedPort)) {
      _selectedPort = null;
    }
    if (_selectedPort == null && ports.isNotEmpty) {
      _selectedPort = ports.first;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Port
            _labeledDropdown(
              label: 'Port',
              value: _selectedPort,
              items: ports,
              width: 110,
              enabled: !isConnected,
              onChanged: (v) => setState(() => _selectedPort = v),
            ),
            // Baud
            _labeledDropdown(
              label: 'Baud',
              value: _baudrate,
              items: _baudrates,
              width: 90,
              enabled: !isConnected,
              onChanged: (v) => setState(() => _baudrate = v!),
            ),
            // Parity
            _labeledDropdown(
              label: 'Parity',
              value: _parity,
              items: _parities,
              width: 80,
              enabled: !isConnected,
              onChanged: (v) => setState(() => _parity = v!),
            ),
            // Data bits
            _labeledDropdown(
              label: 'Data',
              value: _databits,
              items: _databitsOpts,
              width: 60,
              enabled: !isConnected,
              onChanged: (v) => setState(() => _databits = v!),
            ),
            // Stop bits
            _labeledDropdown(
              label: 'Stop',
              value: _stopbits,
              items: _stopbitsOpts,
              width: 60,
              enabled: !isConnected,
              onChanged: (v) => setState(() => _stopbits = v!),
            ),
            // Flow control
            _labeledDropdown(
              label: 'Flow',
              value: _flowcontrol,
              items: _flowOpts,
              width: 90,
              enabled: !isConnected,
              onChanged: (v) => setState(() => _flowcontrol = v!),
            ),
            // Buttons
            ElevatedButton(
              onPressed: isConnected || _selectedPort == null
                  ? null
                  : () => _onOpen(state),
              child: const Text('Open'),
            ),
            ElevatedButton(
              onPressed: isConnected ? () => state.closePort() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Refresh'),
            ),
            // 연결 상태 표시
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onOpen(MonitorState state) {
    if (_selectedPort == null) return;
    state.openPort(
      portName: _selectedPort!,
      baudrate: int.parse(_baudrate),
      parity: _parity,
      databits: int.parse(_databits),
      stopbits: int.parse(_stopbits),
      flowcontrol: _flowcontrol,
    );
  }

  Widget _labeledDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required double width,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:', style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        SizedBox(
          width: width,
          child: DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : null,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
