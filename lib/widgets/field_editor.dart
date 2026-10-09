import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/data_table_entry.dart';
import '../models/mavlink_message_def.dart';
import '../theme/app_theme.dart';

/// Field Value Editor Widget
///
/// Provides appropriate input widget based on data type.
/// For enum fields, displays a dropdown with enum entries.
class FieldEditor extends StatefulWidget {
  /// Data Table entry
  final DataTableEntry entry;

  /// Value change callback
  final ValueChanged<dynamic> onChanged;

  /// Read-only mode
  final bool readOnly;

  /// Enum definition (if this field is an enum type)
  final MavlinkEnumDef? enumDef;

  const FieldEditor({
    super.key,
    required this.entry,
    required this.onChanged,
    this.readOnly = false,
    this.enumDef,
  });

  @override
  State<FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<FieldEditor> {
  late TextEditingController _controller;
  dynamic _lastSendValue;

  @override
  void initState() {
    super.initState();
    _lastSendValue = widget.entry.sendValue;
    _controller = TextEditingController(text: widget.entry.sendValueString);
  }

  @override
  void didUpdateWidget(FieldEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compare actual values, not object references
    if (_lastSendValue != widget.entry.sendValue) {
      _lastSendValue = widget.entry.sendValue;
      _controller.text = widget.entry.sendValueString;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If enum field and enum definition is provided, show dropdown
    if (widget.enumDef != null && !widget.enumDef!.isBitmask) {
      return _buildEnumDropdown();
    }

    // Otherwise show text field
    return _buildTextField();
  }

  Widget _buildEnumDropdown() {
    final enumDef = widget.enumDef!;
    final currentValue = widget.entry.sendValue as int? ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<int>(
      value: enumDef.entries.any((e) => e.value == currentValue)
          ? currentValue
          : null,
      dropdownColor: isDark ? AppTheme.darkDropdownColor : null,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      menuMaxHeight: 300,
      items: enumDef.entries.map((entry) {
        // Shorten the name by removing common prefix
        final displayName = _shortenEnumName(entry.name, enumDef.name);
        return DropdownMenuItem<int>(
          value: entry.value,
          child: Tooltip(
            message: '${entry.name} (${entry.value})\n${entry.description}',
            child: Text(
              displayName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      onChanged: widget.readOnly
          ? null
          : (value) {
              if (value != null) {
                widget.onChanged(value);
              }
            },
    );
  }

  /// Shorten enum entry name by removing common prefix
  String _shortenEnumName(String entryName, String enumName) {
    // Remove enum name prefix if present (e.g., "MAV_TYPE_GENERIC" -> "GENERIC")
    final prefix = '${enumName}_';
    if (entryName.startsWith(prefix)) {
      return entryName.substring(prefix.length);
    }
    // Try common patterns like "MAV_" prefix
    if (entryName.startsWith('MAV_')) {
      final parts = entryName.split('_');
      if (parts.length > 2) {
        // Skip first two parts (e.g., "MAV_TYPE")
        return parts.sublist(2).join('_');
      }
    }
    return entryName;
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(),
        suffixText: widget.entry.units,
      ),
      keyboardType: _getKeyboardType(),
      inputFormatters: _getInputFormatters(),
      onChanged: (value) {
        final parsed = _parseValue(value);
        if (parsed != null) {
          widget.onChanged(parsed);
        }
      },
      onSubmitted: (value) {
        final parsed = _parseValue(value);
        if (parsed != null) {
          widget.onChanged(parsed);
        }
      },
    );
  }

  TextInputType _getKeyboardType() {
    final baseType = widget.entry.baseType;

    if (baseType == 'float' || baseType == 'double') {
      return const TextInputType.numberWithOptions(decimal: true, signed: true);
    }

    if (baseType.contains('int')) {
      return const TextInputType.numberWithOptions(signed: true);
    }

    if (baseType == 'char') {
      return TextInputType.text;
    }

    return TextInputType.number;
  }

  List<TextInputFormatter> _getInputFormatters() {
    final baseType = widget.entry.baseType;

    if (baseType == 'float' || baseType == 'double') {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
      ];
    }

    if (baseType.contains('int')) {
      if (baseType.startsWith('u')) {
        // unsigned
        return [FilteringTextInputFormatter.digitsOnly];
      } else {
        // signed
        return [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))];
      }
    }

    return [];
  }

  dynamic _parseValue(String value) {
    if (value.isEmpty) return null;

    final baseType = widget.entry.baseType;

    try {
      if (baseType == 'float' || baseType == 'double') {
        return double.tryParse(value);
      }

      if (baseType.contains('int') ||
          baseType == 'uint8_t' ||
          baseType == 'int8_t') {
        return int.tryParse(value);
      }

      if (baseType == 'char') {
        return value;
      }

      return int.tryParse(value);
    } catch (e) {
      return null;
    }
  }
}

/// Read-only Field Display Widget
class FieldDisplay extends StatelessWidget {
  /// Data Table entry
  final DataTableEntry entry;

  /// Show current value or send value
  final bool showCurrentValue;

  /// Enum definition (if this field is an enum type)
  final MavlinkEnumDef? enumDef;

  const FieldDisplay({
    super.key,
    required this.entry,
    this.showCurrentValue = true,
    this.enumDef,
  });

  @override
  Widget build(BuildContext context) {
    String displayValue;

    if (showCurrentValue) {
      displayValue = _formatValue(entry.currentValue);
    } else {
      displayValue = _formatValue(entry.sendValue);
    }

    final units = entry.units;

    return Row(
      children: [
        Expanded(
          child: Text(
            displayValue.isEmpty ? '-' : displayValue,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (units != null && units.isNotEmpty)
          Text(
            ' $units',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';

    // If enum, try to show enum name
    if (enumDef != null && value is int) {
      final enumEntry = enumDef!.getEntryByValue(value);
      if (enumEntry != null) {
        // Shorten the name
        final name = enumEntry.name;
        final prefix = '${enumDef!.name}_';
        if (name.startsWith(prefix)) {
          return name.substring(prefix.length);
        }
        return name;
      }
    }

    if (value is double) {
      return value
          .toStringAsFixed(6)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    return value.toString();
  }
}
