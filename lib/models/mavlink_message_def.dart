/// MAVLink message definition
///
/// Represents a message definition parsed from MAVLink XML files.
class MavlinkMessageDef {
  /// Message ID (24-bit)
  final int id;

  /// Message name (e.g., "HEARTBEAT", "SYS_STATUS")
  final String name;

  /// Message description
  final String description;

  /// Field list (in payload order)
  final List<MavlinkFieldDef> fields;

  /// CRC Extra value (for message integrity verification)
  final int crcExtra;

  /// Minimum payload size (bytes)
  final int minPayloadLength;

  const MavlinkMessageDef({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    required this.crcExtra,
    required this.minPayloadLength,
  });

  /// Creates from JSON
  factory MavlinkMessageDef.fromJson(Map<String, dynamic> json) {
    return MavlinkMessageDef(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      fields: (json['fields'] as List<dynamic>)
          .map((f) => MavlinkFieldDef.fromJson(f as Map<String, dynamic>))
          .toList(),
      crcExtra: json['crcExtra'] as int? ?? 0,
      minPayloadLength: json['minPayloadLength'] as int? ?? 0,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'fields': fields.map((f) => f.toJson()).toList(),
        'crcExtra': crcExtra,
        'minPayloadLength': minPayloadLength,
      };

  /// Finds field definition by field name
  MavlinkFieldDef? getField(String fieldName) {
    for (final field in fields) {
      if (field.name == fieldName) return field;
    }
    return null;
  }

  @override
  String toString() => 'MavlinkMessageDef(id: $id, name: $name)';
}

/// MAVLink field definition
///
/// Represents an individual field definition within a MAVLink message.
class MavlinkFieldDef {
  /// Field name
  final String name;

  /// Field data type (e.g., "uint8_t", "int16_t", "float", "char[16]")
  final String type;

  /// Array length (0 if not an array)
  final int arrayLength;

  /// Field description
  final String description;

  /// Unit (e.g., "m/s", "deg", "mV")
  final String? units;

  /// Enum name (if this is an enum field)
  final String? enumName;

  /// Offset in payload (bytes)
  final int offset;

  /// Field size (bytes)
  final int size;

  const MavlinkFieldDef({
    required this.name,
    required this.type,
    this.arrayLength = 0,
    required this.description,
    this.units,
    this.enumName,
    required this.offset,
    required this.size,
  });

  /// Creates from JSON
  factory MavlinkFieldDef.fromJson(Map<String, dynamic> json) {
    return MavlinkFieldDef(
      name: json['name'] as String,
      type: json['type'] as String,
      arrayLength: json['arrayLength'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      units: json['units'] as String?,
      enumName: json['enumName'] as String?,
      offset: json['offset'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'arrayLength': arrayLength,
        'description': description,
        if (units != null) 'units': units,
        if (enumName != null) 'enumName': enumName,
        'offset': offset,
        'size': size,
      };

  /// Checks if this is an array field
  bool get isArray => arrayLength > 0;

  /// Returns base data type (removes array notation)
  String get baseType {
    final bracketIndex = type.indexOf('[');
    return bracketIndex > 0 ? type.substring(0, bracketIndex) : type;
  }

  @override
  String toString() => 'MavlinkFieldDef(name: $name, type: $type)';
}

/// MAVLink enum definition
class MavlinkEnumDef {
  /// Enum name
  final String name;

  /// Enum description
  final String description;

  /// Enum entry list
  final List<MavlinkEnumEntry> entries;

  /// Whether this is a bitmask enum
  final bool isBitmask;

  const MavlinkEnumDef({
    required this.name,
    required this.description,
    required this.entries,
    this.isBitmask = false,
  });

  /// Creates from JSON
  factory MavlinkEnumDef.fromJson(Map<String, dynamic> json) {
    return MavlinkEnumDef(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      entries: (json['entries'] as List<dynamic>)
          .map((e) => MavlinkEnumEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      isBitmask: json['isBitmask'] as bool? ?? false,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
        'isBitmask': isBitmask,
      };

  /// Finds entry by value
  MavlinkEnumEntry? getEntryByValue(int value) {
    for (final entry in entries) {
      if (entry.value == value) return entry;
    }
    return null;
  }
}

/// MAVLink enum entry
class MavlinkEnumEntry {
  /// Entry name
  final String name;

  /// Entry value
  final int value;

  /// Entry description
  final String description;

  const MavlinkEnumEntry({
    required this.name,
    required this.value,
    required this.description,
  });

  /// Creates from JSON
  factory MavlinkEnumEntry.fromJson(Map<String, dynamic> json) {
    return MavlinkEnumEntry(
      name: json['name'] as String,
      value: json['value'] as int,
      description: json['description'] as String? ?? '',
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'description': description,
      };
}

/// MAVLink message specification (complete)
///
/// Represents the complete message specification parsed from XML files.
class MavlinkSpec {
  /// MAVLink version
  final int version;

  /// Dialect version
  final int dialect;

  /// Message definition map (ID → MessageDef)
  final Map<int, MavlinkMessageDef> messages;

  /// Message definition map (name → MessageDef)
  final Map<String, MavlinkMessageDef> messagesByName;

  /// Enum definition map (name → EnumDef)
  final Map<String, MavlinkEnumDef> enums;

  MavlinkSpec({
    required this.version,
    required this.dialect,
    required List<MavlinkMessageDef> messageList,
    required List<MavlinkEnumDef> enumList,
  })  : messages = {for (var m in messageList) m.id: m},
        messagesByName = {for (var m in messageList) m.name: m},
        enums = {for (var e in enumList) e.name: e};

  /// Creates from JSON
  factory MavlinkSpec.fromJson(Map<String, dynamic> json) {
    final messageList = (json['messages'] as List<dynamic>)
        .map((m) => MavlinkMessageDef.fromJson(m as Map<String, dynamic>))
        .toList();
    final enumList = (json['enums'] as List<dynamic>?)
            ?.map((e) => MavlinkEnumDef.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return MavlinkSpec(
      version: json['version'] as int? ?? 2,
      dialect: json['dialect'] as int? ?? 0,
      messageList: messageList,
      enumList: enumList,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'version': version,
        'dialect': dialect,
        'messages': messages.values.map((m) => m.toJson()).toList(),
        'enums': enums.values.map((e) => e.toJson()).toList(),
      };

  /// Finds message definition by message ID
  MavlinkMessageDef? getMessage(int id) => messages[id];

  /// Finds message definition by message name
  MavlinkMessageDef? getMessageByName(String name) => messagesByName[name];

  /// Finds enum definition by enum name
  MavlinkEnumDef? getEnum(String name) => enums[name];

  /// Returns a new MavlinkSpec containing only the specified message names.
  ///
  /// Filters messages by [messageNames] and includes only
  /// enums referenced by those messages.
  MavlinkSpec filterByMessages(Set<String> messageNames) {
    // Filtered message list
    final filteredMessages = messages.values
        .where((m) => messageNames.contains(m.name))
        .toList();

    // Collect enum names referenced by filtered messages
    final referencedEnums = <String>{};
    for (final message in filteredMessages) {
      for (final field in message.fields) {
        if (field.enumName != null) {
          referencedEnums.add(field.enumName!);
        }
      }
    }

    // Include only referenced enums
    final filteredEnums = enums.values
        .where((e) => referencedEnums.contains(e.name))
        .toList();

    return MavlinkSpec(
      version: version,
      dialect: dialect,
      messageList: filteredMessages,
      enumList: filteredEnums,
    );
  }
}
