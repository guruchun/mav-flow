import 'dart:convert';
import 'dart:io';

/// Each field entry in the Data Table
///
/// Manages current value (received) and send value (user-modified) separately.
class DataTableEntry {
  /// TAG - "{MessageName}.{FieldName}" format
  final String tag;

  /// Message name
  final String messageName;

  /// Field name
  final String fieldName;

  /// Data type (e.g., "uint8_t", "int16_t", "float")
  final String dataType;

  /// Unit (e.g., "m/s", "deg", "mV")
  final String? units;

  /// Field description
  final String description;

  /// Enum name (if this is an enum field)
  final String? enumName;

  /// Array length (0 if not an array)
  final int arrayLength;

  /// Current value (received value) - read only
  dynamic currentValue;

  /// Send value (user modifiable)
  dynamic sendValue;

  /// Last receive time
  DateTime? lastUpdated;

  DataTableEntry({
    required this.tag,
    required this.messageName,
    required this.fieldName,
    required this.dataType,
    this.units,
    required this.description,
    this.enumName,
    this.arrayLength = 0,
    this.currentValue,
    this.sendValue,
    this.lastUpdated,
  });

  /// Creates a TAG.
  static String createTag(String messageName, String fieldName) {
    return '$messageName.$fieldName';
  }

  /// Extracts message name from TAG.
  static String? getMessageNameFromTag(String tag) {
    final parts = tag.split('.');
    return parts.isNotEmpty ? parts[0] : null;
  }

  /// Extracts field name from TAG.
  static String? getFieldNameFromTag(String tag) {
    final parts = tag.split('.');
    return parts.length > 1 ? parts.sublist(1).join('.') : null;
  }

  /// Checks if this is an array field
  bool get isArray => arrayLength > 0;

  /// Returns current value as string
  String get currentValueString => _valueToString(currentValue);

  /// Returns send value as string
  String get sendValueString => _valueToString(sendValue);

  /// Converts value to string
  String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    if (value is double) {
      // Display up to 6 decimal places
      return value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return value.toString();
  }

  /// Copies current value to send value
  void copyCurrentToSend() {
    if (currentValue is List) {
      sendValue = List.from(currentValue as List);
    } else {
      sendValue = currentValue;
    }
  }

  /// Returns base data type (removes array notation)
  String get baseType {
    final bracketIndex = dataType.indexOf('[');
    return bracketIndex > 0 ? dataType.substring(0, bracketIndex) : dataType;
  }

  @override
  String toString() =>
      'DataTableEntry(tag: $tag, current: $currentValue, send: $sendValue)';
}

/// Data Table manager
class DataTable {
  /// All entries (TAG to Entry)
  final Map<String, DataTableEntry> entries = {};

  /// Entries by message (MessageName to List of Entry)
  final Map<String, List<DataTableEntry>> _entriesByMessage = {};

  /// Adds entry
  void addEntry(DataTableEntry entry) {
    entries[entry.tag] = entry;
    _entriesByMessage.putIfAbsent(entry.messageName, () => []).add(entry);
  }

  /// Gets entry
  DataTableEntry? getEntry(String tag) => entries[tag];

  /// Gets entries for a message
  List<DataTableEntry> getEntriesByMessage(String messageName) {
    return _entriesByMessage[messageName] ?? [];
  }

  /// All message names
  List<String> get messageNames => _entriesByMessage.keys.toList();

  /// Updates current value (for received messages)
  void updateCurrentValue(String tag, dynamic value) {
    final entry = entries[tag];
    if (entry != null) {
      entry.currentValue = value;
      entry.lastUpdated = DateTime.now();
    }
  }

  /// Updates send value (for user input)
  void updateSendValue(String tag, dynamic value) {
    final entry = entries[tag];
    if (entry != null) {
      entry.sendValue = value;
    }
  }

  /// Copies current values to send values for all fields of a message
  void copyCurrentToSendForMessage(String messageName) {
    final messageEntries = _entriesByMessage[messageName];
    if (messageEntries != null) {
      for (final entry in messageEntries) {
        entry.copyCurrentToSend();
      }
    }
  }

  /// Returns send values for a message as Map
  Map<String, dynamic> getSendValuesForMessage(String messageName) {
    final result = <String, dynamic>{};
    final messageEntries = _entriesByMessage[messageName];
    if (messageEntries != null) {
      for (final entry in messageEntries) {
        result[entry.fieldName] = entry.sendValue ?? entry.currentValue ?? 0;
      }
    }
    return result;
  }

  /// Clears all entries
  void clear() {
    entries.clear();
    _entriesByMessage.clear();
  }

  /// Number of entries
  int get length => entries.length;

  /// All entries as list
  List<DataTableEntry> get allEntries => entries.values.toList();

  /// Saves send values to JSON file.
  Future<void> saveSendValuesToFile(String filePath) async {
    final data = <String, dynamic>{};

    for (final entry in entries.values) {
      if (entry.sendValue != null) {
        data[entry.tag] = entry.sendValue;
      }
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonString);
  }

  /// Loads send values from JSON file.
  Future<void> loadSendValuesFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    for (final mapEntry in data.entries) {
      final tag = mapEntry.key;
      final value = mapEntry.value;
      if (entries.containsKey(tag)) {
        entries[tag]!.sendValue = value;
      }
    }
  }
}
