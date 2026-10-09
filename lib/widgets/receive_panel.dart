import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data_table_entry.dart';
import '../models/mavlink_state.dart';
import '../theme/app_theme.dart';
import 'message_selector.dart';

/// Receive Panel
class ReceivePanel extends StatefulWidget {
  const ReceivePanel({super.key});

  @override
  State<ReceivePanel> createState() => _ReceivePanelState();
}

class _ReceivePanelState extends State<ReceivePanel> {
  String? _selectedMessage;
  String _searchText = '';
  String? _lastRoleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final roleConfig = state.currentRoleConfig;
        final allEntries = state.dataTable.allEntries;

        // RX message filter
        final rxMessages = roleConfig.rxMessages;

        // Reset selected message when role changes
        if (_lastRoleId != state.currentRoleId) {
          _lastRoleId = state.currentRoleId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedMessage = null;
              });
            }
          });
        }

        // Validate selection
        final validSelection = _selectedMessage != null && 
            rxMessages.contains(_selectedMessage);
        final effectiveSelection = validSelection ? _selectedMessage : null;

        // Filtered entries
        var filteredEntries = allEntries.where((e) {
          // Message filter
          if (effectiveSelection != null && e.messageName != effectiveSelection) {
            return false;
          }
          // RX messages only
          if (!rxMessages.contains(e.messageName)) {
            return false;
          }
          // Search filter
          if (_searchText.isNotEmpty) {
            final searchLower = _searchText.toLowerCase();
            return e.tag.toLowerCase().contains(searchLower) ||
                e.description.toLowerCase().contains(searchLower);
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (fixed height to match TX panel)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: theme.rxPanelHeader,
              alignment: Alignment.centerLeft,
              child: const Text(
                'RX Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),

            // Filter area
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Message label and filter
                  const Text('Message: '),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: MessageSelector(
                      messages: rxMessages,
                      selectedMessage: effectiveSelection,
                      onChanged: (value) {
                        setState(() => _selectedMessage = value);
                      },
                      hint: 'All',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() => _searchText = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: theme.tableHeaderBackground,
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Field',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 2,
                      child: Text('Value',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(
                      width: 50,
                      child: Text('Unit',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      flex: 3,
                      child: Text('Description',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Data list
            Expanded(
              child: filteredEntries.isEmpty
                  ? const Center(child: Text('No data'))
                  : ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return _buildRow(context, state, entry, index, effectiveSelection == null);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, MavlinkState state, DataTableEntry entry, int index, bool showFullTag) {
    final theme = Theme.of(context);
    final isEven = index % 2 == 0;

    // Show full tag (message.field) when All is selected, otherwise just field name
    final fieldDisplay = showFullTag ? entry.tag : entry.fieldName;

    // Get display value - convert enum to text if applicable
    String valueDisplay = entry.currentValueString.isEmpty ? '-' : entry.currentValueString;
    if (entry.enumName != null && state.spec != null && entry.currentValue != null) {
      final enumDef = state.spec!.getEnum(entry.enumName!);
      if (enumDef != null) {
        final intValue = entry.currentValue is int ? entry.currentValue as int : null;
        if (intValue != null) {
          final enumEntry = enumDef.entries.where((e) => e.value == intValue).firstOrNull;
          if (enumEntry != null) {
            // Shorten enum name
            valueDisplay = _shortenEnumName(enumEntry.name, enumDef.name);
          }
        }
      }
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: isEven ? theme.tableRowEven : theme.tableRowOdd,
      child: Row(
        children: [
          // Field
          Expanded(
            flex: 3,
            child: Text(
              fieldDisplay,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Current value
          Expanded(
            flex: 2,
            child: Text(
              valueDisplay,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: entry.lastUpdated != null &&
                        DateTime.now().difference(entry.lastUpdated!).inSeconds <
                            2
                    ? Colors.green[400]
                    : theme.primaryTextColor,
              ),
            ),
          ),
          // Unit
          SizedBox(
            width: 50,
            child: Center(
              child: Text(
                entry.units ?? '',
                style: TextStyle(fontSize: 11, color: theme.secondaryTextColor),
              ),
            ),
          ),
          // Description
          Expanded(
            flex: 3,
            child: Text(
              entry.description,
              style: TextStyle(fontSize: 11, color: theme.secondaryTextColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
}
