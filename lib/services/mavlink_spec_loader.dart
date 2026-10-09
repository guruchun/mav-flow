import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

import '../models/mavlink_message_def.dart';

/// MAVLink XML 규격 파일을 파싱하여 JSON으로 변환하는 로더
///
/// MAVLink 표준 XML 파일(common.xml 등)을 파싱하여 앱에서 사용할 수 있는
/// JSON 형식으로 변환합니다.
class MavlinkSpecLoader {
  /// Assets에서 JSON 규격 파일을 로드합니다. (런타임 사용)
  ///
  /// [assetPath]는 assets 폴더 내 상대 경로입니다.
  /// 예: 'mavlink/messages.json'
  static Future<MavlinkSpec> loadFromAssetJson(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return MavlinkSpec.fromJson(json);
  }

  /// 파일 시스템에서 JSON 규격 파일을 로드합니다.
  ///
  /// [filePath]는 절대 경로 또는 상대 경로입니다.
  static Future<MavlinkSpec> loadFromFileJson(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return MavlinkSpec.fromJson(json);
  }

  /// MAVLink XML 파일들을 파싱하여 통합된 MavlinkSpec을 생성합니다.
  ///
  /// [xmlPaths]는 XML 파일 경로 목록입니다.
  /// 여러 XML 파일을 지정하면 모든 메시지와 열거형이 통합됩니다.
  static Future<MavlinkSpec> loadFromXmlFiles(List<String> xmlPaths) async {
    final allMessages = <MavlinkMessageDef>[];
    final allEnums = <MavlinkEnumDef>[];
    int version = 2;
    int dialect = 0;

    for (final path in xmlPaths) {
      final file = File(path);
      if (!await file.exists()) {
        throw FileSystemException('XML 파일을 찾을 수 없습니다', path);
      }

      final xmlString = await file.readAsString();
      final document = XmlDocument.parse(xmlString);

      final result = _parseXmlDocument(document);
      version = result.version;
      dialect = result.dialect;
      allMessages.addAll(result.messages);
      allEnums.addAll(result.enums);
    }

    // 중복 제거 (같은 ID의 메시지는 나중 것이 우선)
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

  /// XML 파일을 파싱하여 JSON 파일로 저장합니다.
  ///
  /// [xmlPaths]는 XML 파일 경로 목록입니다.
  /// [outputJsonPath]는 출력 JSON 파일 경로입니다.
  /// [messageFilter]가 제공되면 해당 메시지 이름만 포함합니다.
  static Future<void> convertXmlToJson({
    required List<String> xmlPaths,
    required String outputJsonPath,
    Set<String>? messageFilter,
  }) async {
    final spec = await loadFromXmlFiles(xmlPaths);
    
    // 필터가 있으면 해당 메시지만 추출
    final filteredSpec = messageFilter != null
        ? spec.filterByMessages(messageFilter)
        : spec;
    
    final json = filteredSpec.toJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(json);

    final outputFile = File(outputJsonPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(jsonString);
  }

  /// role_config.json에서 모든 메시지 이름을 추출합니다.
  ///
  /// 모든 역할의 txMessages와 rxMessages를 합집합으로 반환합니다.
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

  /// Assets에서 role_config.json의 메시지 이름을 추출합니다.
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

  /// XML 문서를 파싱합니다.
  static _ParseResult _parseXmlDocument(XmlDocument document) {
    final mavlink = document.findElements('mavlink').first;

    // 버전 정보
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

    // 열거형 파싱
    final enums = <MavlinkEnumDef>[];
    final enumsElement = mavlink.findElements('enums').firstOrNull;
    if (enumsElement != null) {
      for (final enumElement in enumsElement.findElements('enum')) {
        enums.add(_parseEnum(enumElement));
      }
    }

    // 메시지 파싱
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

  /// 열거형 XML 요소를 파싱합니다.
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

  /// 메시지 XML 요소를 파싱합니다.
  static MavlinkMessageDef _parseMessage(XmlElement element) {
    final id = int.tryParse(element.getAttribute('id') ?? '0') ?? 0;
    final name = element.getAttribute('name') ?? '';

    String description = '';
    final descElement = element.findElements('description').firstOrNull;
    if (descElement != null) {
      description = descElement.innerText.trim();
    }

    // 필드 파싱 (순서 유지)
    final fields = <MavlinkFieldDef>[];
    int offset = 0;

    for (final fieldElement in element.findElements('field')) {
      final field = _parseField(fieldElement, offset);
      fields.add(field);
      offset += field.size;
    }

    // 필드 재정렬 (MAVLink 직렬화 순서: 크기 내림차순, 같은 크기면 원래 순서)
    // 실제 직렬화에서는 큰 타입이 먼저 오도록 재정렬됨
    final sortedFields = _sortFieldsForSerialization(fields);

    // 오프셋 재계산
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

    // CRC Extra 계산
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

  /// 필드 XML 요소를 파싱합니다.
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

    // 배열 길이 파싱 (예: "char[16]" → arrayLength=16)
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

  /// 필드 크기를 계산합니다.
  static int _calculateFieldSize(String baseType, int arrayLength) {
    final count = arrayLength > 0 ? arrayLength : 1;
    final unitSize = _getTypeSize(baseType);
    return unitSize * count;
  }

  /// 기본 타입의 크기를 반환합니다.
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

  /// MAVLink 직렬화 순서에 맞게 필드를 재정렬합니다.
  ///
  /// MAVLink는 메모리 정렬을 위해 필드를 크기 내림차순으로 재정렬합니다.
  static List<MavlinkFieldDef> _sortFieldsForSerialization(
      List<MavlinkFieldDef> fields) {
    // 확장 필드(extensions 이후)는 별도 처리 필요하지만 여기서는 단순화
    final sorted = List<MavlinkFieldDef>.from(fields);

    // 타입별 기본 크기 기준으로 정렬 (내림차순)
    sorted.sort((a, b) {
      final sizeA = _getTypeSize(a.baseType);
      final sizeB = _getTypeSize(b.baseType);
      if (sizeA != sizeB) {
        return sizeB.compareTo(sizeA); // 내림차순
      }
      // 같은 크기면 원래 순서 유지 (stable sort가 아니므로 인덱스 비교는 어려움)
      return 0;
    });

    return sorted;
  }

  /// CRC Extra 값을 계산합니다.
  ///
  /// MAVLink 메시지 검증을 위한 CRC Extra 값을 계산합니다.
  /// 계산식: CRC-16/MCRF4XX(message_name + " " + field_types + field_names)
  static int _calculateCrcExtra(String messageName, List<MavlinkFieldDef> fields) {
    // X25 CRC 초기화
    int crc = 0xFFFF;

    // 메시지 이름 + ' '
    for (final char in '$messageName '.codeUnits) {
      crc = _crcAccumulate(char, crc);
    }

    // 각 필드의 타입과 이름
    for (final field in fields) {
      final baseType = field.baseType;

      // 타입 문자열
      for (final char in '$baseType '.codeUnits) {
        crc = _crcAccumulate(char, crc);
      }

      // 필드 이름
      for (final char in '$field.name '.codeUnits) {
        crc = _crcAccumulate(char, crc);
      }

      // 배열이면 배열 크기도 포함
      if (field.isArray) {
        crc = _crcAccumulate(field.arrayLength, crc);
      }
    }

    return ((crc & 0xFF) ^ (crc >> 8)) & 0xFF;
  }

  /// CRC-16/MCRF4XX 누적 계산
  static int _crcAccumulate(int byte, int crc) {
    final tmp = byte ^ (crc & 0xFF);
    final tmp2 = tmp ^ ((tmp << 4) & 0xFF);
    return ((crc >> 8) ^ (tmp2 << 8) ^ (tmp2 << 3) ^ (tmp2 >> 4)) & 0xFFFF;
  }
}

/// XML 파싱 결과
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
