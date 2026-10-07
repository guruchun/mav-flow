import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitor_state.dart';

/// 메시지 유형 필터 + 필드 검색 패널.
///
/// Python _create_filter_panel()에 대응한다.
class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key});

  static const _filterTypes = ['All', 'Base', 'FuelCell', 'Cells'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MonitorState>();

    return Card(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            const Text('Type:', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            ..._filterTypes.map(
              (type) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(type),
                  selected: state.filterType == type,
                  onSelected: (_) => state.setFilterType(type),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Text('Search:', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(),
                  hintText: 'field name...',
                ),
                onChanged: state.setSearchText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
