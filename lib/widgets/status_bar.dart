import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitor_state.dart';

/// 하단 상태바 — 패킷 카운트, CRC 에러, 수신율 표시.
///
/// Python status_bar ttk.Label에 대응한다.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MonitorState>();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          _statChip(
            icon: Icons.inbox,
            label: 'Packets',
            value: state.packetCount.toString(),
            color: Colors.blue,
          ),
          const SizedBox(width: 20),
          _statChip(
            icon: Icons.error_outline,
            label: 'CRC Errors',
            value: state.crcErrorCount.toString(),
            color: state.crcErrorCount > 0 ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 20),
          _statChip(
            icon: Icons.speed,
            label: 'Rate',
            value: '${state.packetRate.toStringAsFixed(1)} Hz',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
