import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitor_state.dart';
import '../models/field_value.dart';

/// 파싱된 필드 값을 표시하는 데이터 테이블 패널.
///
/// Python ttk.Treeview (6컬럼)에 대응한다.
/// 컬럼: Field Name | Raw Value | Converted | Data Type | Scale | Offset
class DataTablePanel extends StatelessWidget {
  const DataTablePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MonitorState>();

    if (state.specError != null) {
      return Center(
        child: Text(
          'YAML 규격 로딩 실패:\n${state.specError}',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (state.spec == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final rows = state.filteredFields;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          _TableHeader(),
          // 데이터 행 (스크롤)
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No fields to display.'))
                : _FieldListView(rows: rows),
          ),
        ],
      ),
    );
  }
}

// 컬럼 폭 (논리 픽셀)
const _colWidths = [220.0, 100.0, 120.0, 90.0, 70.0, 70.0];
const _colHeaders = [
  'Field Name',
  'Raw Value',
  'Converted',
  'Data Type',
  'Scale',
  'Offset',
];

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          for (int i = 0; i < _colHeaders.length; i++)
            _HeaderCell(
              text: _colHeaders[i],
              width: _colWidths[i],
              rightAlign: i > 0,
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final bool rightAlign;

  const _HeaderCell({
    required this.text,
    required this.width,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Text(
          text,
          textAlign: rightAlign ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}

class _FieldListView extends StatelessWidget {
  final List<FieldRow> rows;

  const _FieldListView({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: rows.length,
      itemExtent: 26,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isEven = index.isEven;
        return Container(
          color: isEven
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              _DataCell(text: row.name, width: _colWidths[0], rightAlign: false),
              _DataCell(text: row.raw, width: _colWidths[1]),
              _DataCell(text: row.converted, width: _colWidths[2]),
              _DataCell(text: row.dataType, width: _colWidths[3]),
              _DataCell(text: row.scale, width: _colWidths[4]),
              _DataCell(text: row.offset, width: _colWidths[5]),
            ],
          ),
        );
      },
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final double width;
  final bool rightAlign;

  const _DataCell({
    required this.text,
    required this.width,
    this.rightAlign = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          text,
          textAlign: rightAlign ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
