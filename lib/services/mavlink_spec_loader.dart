import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

import '../models/mavlink_message_def.dart';

/// Loader that parses MAVLink XML spec files and converts to JSON
///
/// Parses MAVLink standard XML files (common.xml, etc.) and converts them
/// to JSON format usable by the app.
class MavlinkSpecLoader {
  /// Loads JSON spec file from assets. (for runtime use)
  ///
  /// [assetPath] is the relative path within assets folder.
  /// Example: 'mavlink/messages.json'
  static Future<MavlinkSpec> loadFromAssetJson(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return MavlinkSpec.fromJson(json);
  }

  /// Loads JSON spec file from filesystem.
  ///
  /// [filePath] is an absolute or relative path.
  static Future<MavlinkSpec> loadFromFileJson(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return MavlinkSpec.fromJson(json);
  }

  /// Parses MAVLink XML files and creates a unified MavlinkSpec.
  ///
  /// [xmlPaths] is a list of XML file paths.
  /// If multiple XML files are specified, all messages and enums are merged.
  static Future<MavlinkSpec> loadFromXmlFiles(List<String> xmlPaths) async {
    final allMessages = <MavlinkMessageDef>[];
    final allEnums = <MavlinkEnumDef>[];
    int version = 2;
    int dialect = 0;

    for (final path in xmlPaths) {
      final file = File(path);
      if (!await file.exists()) {
        throw FileSystemException('XML file not found', path);
      }

      final xmlString = await file.readAsString();
      final document = XmlDocument.parse(xmlString);

      final result = _parseXmlDocument(document);
      version = result.version;
      dialect = result.dialect;
      allMessages.addAll(result.messages);
      allEnums.addAll(result.enums);
    }

    // Remove duplicates (later messages with same ID take precedence)
    final messagesById = <int, MavlinkMessageDef>{};
    for (final msg in allMessages) {
      messagesById[msg.id] = msg;
    }

    final enumsByName = <String, MavlinkEnumDef>{};
    for (final e in allEnums) {
      enumsByName[e.name] = e;
    }

    return MavlinkSpec(
      version: version,
      dialect: dialect,
      messageList: messagesById.values.toList(),
      enumList: enumsByName.values.toList(),
    );
  }

  /// Parses XML files and saves to JSON file.
  ///
  /// [xmlPaths] is a list of XML file paths.
  /// [outputJsonPath] is the output JSON file path.
  /// If [messageFilter] is provided, only those message names are included.
  static Future<void> convertXmlToJson({
    required List<String> xmlPaths,
    required String outputJsonPath,
    Set<String>? messageFilter,
  }) async {
    final spec = await loadFromXmlFiles(xmlPaths);
    
    // If filter is provided, extract only those messages
    final filteredSpec = messageFilter != null
        ? spec.filterByMessages(messageFilter)
        : spec;
    
    final json = filteredSpec.toJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(json);

    final outputFile = File(outputJsonPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(jsonString);
  }

  /// Extracts all message names from role_config.json.
  ///
  /// Returns union of all roles' txMessages and rxMessages.
  static Future<Set<String>> extractMessageNamesFromRoleConfig(
      String roleConfigPath) async {
    final file = File(roleConfigPath);
    final jsonString = await file.readAsString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final roles = json['roles'] as Map<String, dynamic>?;

    if (roles == null) return {};

    final messageNames = <String>{};
    for (final roleData in roles.values) {
      final roleMap = roleData as Map<String, dynamic>;
      final txMessages = (roleMap['txMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final rxMessages = (roleMap['rxMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      messageNames.addAll(txMessages);
      messageNames.addAll(rxMessages);
    }

    return messageNames;
  }

  /// Extracts message names from role_config.json in assets.
  static Future<Set<String>> extractMessageNamesFromRoleConfigAsset(
      String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final roles = json['roles'] as Map<String, dynamic>?;

    if (roles == null) return {};

    final messageNames = <String>{};
    for (final roleData in roles.values) {
      final roleMap = roleData as Map<String, dynamic>;
      final txMessages = (roleMap['txMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final rxMessages = (roleMap['rxMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      messageNames.addAll(txMessages);
      messageNames.addAll(rxMessages);
    }

    return messageNames;
  }

  /// Parses XML document.
  static _ParseResult _parseXmlDocument(XmlDocument document) {
    final mavlink = document.findElements('mavlink').first;

    // Version info
    int version = 2;
    int dialect = 0;

    final versionElement = mavlink.findElements('version').firstOrNull;
    if (versionElement != null) {
      version = int.tryParse(versionElement.innerText) ?? 2;
    }

    final dialectElement = mavlink.findElements('dialect').firstOrNull;
    if (dialectElement != null) {
      dialect = int.tryParse(dialectElement.innerText) ?? 0;
    }

    // Parse enums
    final enums = <MavlinkEnumDef>[];
    final enumsElement = mavlink.findElements('enums').firstOrNull;
    if (enumsElement != null) {
      for (final enumElement in enumsElement.findElements('enum')) {
        enums.add(_parseEnum(enumElement));
      }
    }

    // Parse messages
    final messages = <MavlinkMessageDef>[];
    final messagesElement = mavlink.findElements('messages').firstOrNull;
    if (messagesElement != null) {
      for (final msgElement in messagesElement.findElements('message')) {
        messages.add(_parseMessage(msgElement));
      }
    }

    return _ParseResult(
      version: version,
      dialect: dialect,
      messages: messages,
      enums: enums,
    );
  }

  /// Parses enum XML element.
  static MavlinkEnumDef _parseEnum(XmlElement element) {
    final name = element.getAttribute('name') ?? '';
    final bitmask = element.getAttribute('bitmask') == 'true';

    String description = '';
    final descElement = element.findElements('description').firstOrNull;
    if (descElement != null) {
      description = descElement.innerText.trim();
    }

    final entries = <MavlinkEnumEntry>[];
    for (final entryElement in element.findElements('entry')) {
      final entryName = entryElement.getAttribute('name') ?? '';
      final entryValue =
          int.tryParse(entryElement.getAttribute('value') ?? '0') ?? 0;

      String entryDesc = '';
      final entryDescElement = entryElement.findElements('description').firstOrNull;
      if (entryDescElement != null) {
        entryDesc = entryDescElement.innerText.trim();
      }

      entries.add(MavlinkEnumEntry(
        name: entryName,
        value: entryValue,
        description: entryDesc,
      ));
    }

    return MavlinkEnumDef(
      name: name,
      description: description,
      entries: entries,
      isBitmask: bitmask,
    );
  }

  /// Parses message XML element.
  static MavlinkMessageDef _parseMessage(XmlElement element) {
    final id = int.tryParse(element.getAttribute('id') ?? '0') ?? 0;
    final name = element.getAttribute('name') ?? '';

    String description = '';
    final descElement = element.findElements('description').firstOrNull;
    if (descElement != null) {
      description = descElement.innerText.trim();
    }

    // Parse fields (maintain order)
    final fields = <MavlinkFieldDef>[];
    int offset = 0;

    for (final fieldElement in element.findElements('field')) {
      final field = _parseField(fieldElement, offset);
      fields.add(field);
      offset += field.size;
    }

    // Reorder fields (MAVLink serialization order: size descending, same size keeps original order)
    // In actual serialization, larger types come first
    final sortedFields = _sortFieldsForSerialization(fields);

    // Recalculate offsets
    int newOffset = 0;
    final fieldsWithOffset = <MavlinkFieldDef>[];
    for (final field in sortedFields) {
      fieldsWithOffset.add(MavlinkFieldDef(
        name: field.name,
        type: field.type,
        arrayLength: field.arrayLength,
        description: field.description,
        units: field.units,
        enumName: field.enumName,
        offset: newOffset,
        size: field.size,
      ));
      newOffset += field.size;
    }

    // Calculate CRC Extra
    final crcExtra = _calculateCrcExtra(name, fieldsWithOffset);

    return MavlinkMessageDef(
      id: id,
      name: name,
      description: description,
      fields: fieldsWithOffset,
      crcExtra: crcExtra,
      minPayloadLength: newOffset,
    );
  }

  /// Parses field XML element.
  static MavlinkFieldDef _parseField(XmlElement element, int offset) {
    final type = element.getAttribute('type') ?? 'uint8_t';
    final name = element.getAttribute('name') ?? '';
    final units = element.getAttribute('units');
    final enumName = element.getAttribute('enum');

    String description = '';
    final descText = element.innerText.trim();
    if (descText.isNotEmpty) {
      description = descText;
    }

    // Parse array length (e.g., "char[16]" → arrayLength=16)
    int arrayLength = 0;
    String baseType = type;

    final bracketMatch = RegExp(r'\[(\d+)\]').firstMatch(type);
    if (bracketMatch != null) {
      arrayLength = int.tryParse(bracketMatch.group(1) ?? '0') ?? 0;
      baseType = type.substring(0, bracketMatch.start);
    }

    final size = _calculateFieldSize(baseType, arrayLength);

    return MavlinkFieldDef(
      name: name,
      type: type,
      arrayLength: arrayLength,
      description: description,
      units: units,
      enumName: enumName,
      offset: offset,
      size: size,
    );
  }

  /// Calculates field size.
  static int _calculateFieldSize(String baseType, int arrayLength) {
    final count = arrayLength > 0 ? arrayLength : 1;
    final unitSize = _getTypeSize(baseType);
    return unitSize * count;
  }

  /// Returns base type size.
  static int _getTypeSize(String type) {
    switch (type) {
      case 'int8_t':
      case 'uint8_t':
      case 'char':
        return 1;
      case 'int16_t':
      case 'uint16_t':
        return 2;
      case 'int32_t':
      case 'uint32_t':
      case 'float':
        return 4;
      case 'int64_t':
      case 'uint64_t':
      case 'double':
        return 8;
      default:
        return 1;
    }
  }

  /// Reorders fields for MAVLink serialization order.
  ///
  /// MAVLink reorders fields by size descending for memory alignment.
  static List<MavlinkFieldDef> _sortFieldsForSerialization(
      List<MavlinkFieldDef> fields) {
    // Extension fields (after extensions) need separate handling but simplified here
    final sorted = List<MavlinkFieldDef>.from(fields);

    // Sort by base type size (descending)
    sorted.sort((a, b) {
      final sizeA = _getTypeSize(a.baseType);
      final sizeB = _getTypeSize(b.baseType);
      if (sizeA != sizeB) {
        return sizeB.compareTo(sizeA); // Descending
      }
      // Same size keeps original order (index comparison difficult as not stable sort)
      return 0;
    });

    return sorted;
  }

  /// Calculates CRC Extra value.
  ///
  /// Calculates CRC Extra value for MAVLink message verification.
  /// Formula: CRC-16/MCRF4XX(message_name + " " + field_types + field_names)
  static int _calculateCrcExtra(String messageName, List<MavlinkFieldDef> fields) {
    // X25 CRC initialization
    int crc = 0xFFFF;

    // Message name + ' '
    for (final char in '$messageName '.codeUnits) {
      crc = _crcAccumulate(char, crc);
    }

    // Each field's type and name
    for (final field in fields) {
      final baseType = field.baseType;

      // Type string
      for (final char in '$baseType '.codeUnits) {
        crc = _crcAccumulate(char, crc);
      }

      // Field name
      for (final char in '$field.name '.codeUnits) {
        crc = _crcAccumulate(char, crc);
      }

      // Include array size if array
      if (field.isArray) {
        crc = _crcAccumulate(field.arrayLength, crc);
      }
    }

    return ((crc & 0xFF) ^ (crc >> 8)) & 0xFF;
  }

  /// CRC-16/MCRF4XX accumulate calculation
  static int _crcAccumulate(int byte, int crc) {
    final tmp = byte ^ (crc & 0xFF);
    final tmp2 = tmp ^ ((tmp << 4) & 0xFF);
    return ((crc >> 8) ^ (tmp2 << 8) ^ (tmp2 << 3) ^ (tmp2 >> 4)) & 0xFFFF;
  }
}

/// XML parsing result
class _ParseResult {
  final int version;
  final int dialect;
  final List<MavlinkMessageDef> messages;
  final List<MavlinkEnumDef> enums;

  _ParseResult({
    required this.version,
    required this.dialect,
    required this.messages,
    required this.enums,
  });
}
