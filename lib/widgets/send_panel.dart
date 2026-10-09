import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data_table_entry.dart';
import '../models/mavlink_message_def.dart';
import '../models/mavlink_state.dart';
import '../theme/app_theme.dart';
import 'auto_send_list.dart';
import 'field_editor.dart';
import 'message_selector.dart';

/// JSON file type group for file dialogs
final _jsonTypeGroup = XTypeGroup(
  label: 'JSON files',
  extensions: ['json'],
);

/// Get the directory where the executable is located
String _getAppDirectory() {
  // Directory.current gives the current working directory,
  // which is typically the exe directory when run from Explorer
  return Directory.current.path;
}

/// Send Panel
class SendPanel extends StatefulWidget {
  const SendPanel({super.key});

  @override
  State<SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends State<SendPanel> {
  String? _selectedMessage;
  String _searchText = '';
  bool _showAutoSendList = false;
  String? _lastRoleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final roleConfig = state.currentRoleConfig;
        final txMessages = roleConfig.txMessages;

        // Reset selected message when role changes
        if (_lastRoleId != state.currentRoleId) {
          _lastRoleId = state.currentRoleId;
          // Use post-frame callback to avoid setState during build
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
            txMessages.contains(_selectedMessage);
        final effectiveSelection = validSelection ? _selectedMessage : null;

        // Get all TX entries
        final allEntries = state.dataTable.allEntries;

        // Filter entries for TX messages
        var filteredEntries = allEntries.where((e) {
          // Message filter
          if (effectiveSelection != null && e.messageName != effectiveSelection) {
            return false;
          }
          // TX messages only
          if (!txMessages.contains(e.messageName)) {
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

        // Can send only when a specific message is selected and connected
        final canSend = state.isConnected && effectiveSelection != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Load/Save buttons (fixed height to match RX panel)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: theme.txPanelHeader,
              child: Row(
                children: [
                  const Text(
                    'TX Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  // Load button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_open, size: 16),
                    label: const Text('Load'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: state.isRoleSelected
                        ? () => _loadFromFile(context, state)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Save button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: state.isRoleSelected
                        ? () => _saveToFile(context, state)
                        : null,
                  ),
                  const Spacer(),
                  // Auto-send list toggle
                  TextButton.icon(
                    icon: Icon(
                      _showAutoSendList ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: const Text('Auto Send'),
                    onPressed: () {
                      setState(() => _showAutoSendList = !_showAutoSendList);
                    },
                  ),
                ],
              ),
            ),

            // Auto-send list (collapsible)
            if (_showAutoSendList)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: const AutoSendList(),
              ),

            // Filter area (same as RX panel)
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
                      messages: txMessages,
                      selectedMessage: effectiveSelection,
                      onChanged: (value) {
                        setState(() => _selectedMessage = value);
                      },
                      showAllOption: true,
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
                        return _buildFieldRow(context, state, entry, index, effectiveSelection == null);
                      },
                    ),
            ),

            // Send button
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                    onPressed: canSend
                        ? () => state.sendMessageByName(_selectedMessage!)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldRow(
    BuildContext context,
    MavlinkState state,
    DataTableEntry entry,
    int index,
    bool showFullTag,
  ) {
    final theme = Theme.of(context);
    final isEven = index % 2 == 0;

    // Show full tag (message.field) when All is selected, otherwise just field name
    final fieldDisplay = showFullTag ? entry.tag : entry.fieldName;

    // Get enum definition if this field has an enum type
    MavlinkEnumDef? enumDef;
    if (entry.enumName != null && state.spec != null) {
      enumDef = state.spec!.getEnum(entry.enumName!);
    }

    // Check if this is a bitmask field
    final isBitmask = enumDef != null && enumDef.isBitmask;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          // Value editor
          Expanded(
            flex: 2,
            child: SizedBox(
              height: double.infinity,
              child: FieldEditor(
                entry: entry,
                enumDef: enumDef,
                onChanged: (value) {
                  state.updateSendValue(entry.tag, value);
                },
              ),
            ),
          ),
          // Unit or Bitmask edit icon
          SizedBox(
            width: 50,
            child: isBitmask
                ? Center(
                    child: IconButton(
                      icon: Icon(
                        Icons.edit_note,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      tooltip: 'Edit bitmask',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showBitmaskEditor(
                        context,
                        state,
                        entry,
                        enumDef!,
                      ),
                    ),
                  )
                : Center(
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

  Future<void> _showBitmaskEditor(
    BuildContext context,
    MavlinkState state,
    DataTableEntry entry,
    MavlinkEnumDef enumDef,
  ) async {
    final currentValue = entry.sendValue as int? ?? 0;
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => BitmaskEditorDialog(
        title: entry.fieldName,
        enumDef: enumDef,
        initialValue: currentValue,
      ),
    );

    if (result != null) {
      state.updateSendValue(entry.tag, result);
    }
  }

  Future<void> _loadFromFile(BuildContext context, MavlinkState state) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [_jsonTypeGroup],
        initialDirectory: _getAppDirectory(),
        confirmButtonText: 'Load',
      );

      if (file != null) {
        await state.loadSendValuesFromFile(file.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TX values loaded')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveToFile(BuildContext context, MavlinkState state) async {
    try {
      // Suggest filename with role ID
      final roleId = state.currentRoleId;
      final suggestedName = 'tx_${roleId}_values.json';

      final location = await getSaveLocation(
        acceptedTypeGroups: [_jsonTypeGroup],
        initialDirectory: _getAppDirectory(),
        suggestedName: suggestedName,
        confirmButtonText: 'Save',
      );

      if (location != null) {
        // Ensure .json extension
        var filePath = location.path;
        if (!filePath.toLowerCase().endsWith('.json')) {
          filePath = '$filePath.json';
        }
        await state.saveSendValuesToFile(filePath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TX values saved')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Bitmask Editor Dialog
class BitmaskEditorDialog extends StatefulWidget {
  final String title;
  final MavlinkEnumDef enumDef;
  final int initialValue;

  const BitmaskEditorDialog({
    super.key,
    required this.title,
    required this.enumDef,
    required this.initialValue,
  });

  @override
  State<BitmaskEditorDialog> createState() => _BitmaskEditorDialogState();
}

class _BitmaskEditorDialogState extends State<BitmaskEditorDialog> {
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Edit ${widget.title}'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current value display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Text('Value: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '$_currentValue',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '(0x${_currentValue.toRadixString(16).toUpperCase()})',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: theme.tableHeaderBackground,
              child: const Row(
                children: [
                  SizedBox(width: 40, child: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 60, child: Text('Bit', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            // Bit list
            Expanded(
              child: Builder(
                builder: (context) {
                  // Sort entries by bit value (ascending order)
                  final sortedEntries = List.of(widget.enumDef.entries)
                    ..sort((a, b) => a.value.compareTo(b.value));
                  
                  return ListView.builder(
                    itemCount: sortedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = sortedEntries[index];
                      final bitPosition = _getBitPosition(entry.value);
                      final isChecked = (_currentValue & entry.value) != 0;
                      final isEven = index % 2 == 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: isEven ? theme.tableRowEven : theme.tableRowOdd,
                        child: Row(
                          children: [
                            // Checkbox
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: isChecked,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _currentValue |= entry.value;
                                    } else {
                                      _currentValue &= ~entry.value;
                                    }
                                  });
                                },
                              ),
                            ),
                            // Bit position
                            SizedBox(
                              width: 60,
                              child: Text(
                                bitPosition >= 0 ? '$bitPosition' : '${entry.value}',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                            // Description
                            Expanded(
                              child: Tooltip(
                                message: entry.description,
                                child: Text(
                                  _shortenEnumName(entry.name, widget.enumDef.name),
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_currentValue),
          child: const Text('OK'),
        ),
      ],
    );
  }

  /// Get bit position from value (e.g., 1->0, 2->1, 4->2, 8->3)
  int _getBitPosition(int value) {
    if (value <= 0) return -1;
    int position = 0;
    int v = value;
    while ((v & 1) == 0) {
      v >>= 1;
      position++;
    }
    // Check if it's a power of 2
    if (v == 1) {
      return position;
    }
    return -1; // Not a single bit
  }

  /// Shorten enum entry name by removing common prefix
  String _shortenEnumName(String entryName, String enumName) {
    final prefix = '${enumName}_';
    if (entryName.startsWith(prefix)) {
      return entryName.substring(prefix.length);
    }
    if (entryName.startsWith('MAV_')) {
      final parts = entryName.split('_');
      if (parts.length > 2) {
        return parts.sublist(2).join('_');
      }
    }
    return entryName;
  }
}
