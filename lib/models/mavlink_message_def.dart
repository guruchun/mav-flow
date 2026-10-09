/// MAVLink 메시지 정의
///
/// MAVLink XML 파일에서 파싱된 메시지 정의를 나타냅니다.
class MavlinkMessageDef {
  /// 메시지 ID (24-bit)
  final int id;

  /// 메시지 이름 (예: "HEARTBEAT", "SYS_STATUS")
  final String name;

  /// 메시지 설명
  final String description;

  /// 필드 목록 (페이로드 순서대로)
  final List<MavlinkFieldDef> fields;

  /// CRC Extra 값 (메시지 무결성 검증용)
  final int crcExtra;

  /// 페이로드 최소 크기 (바이트)
  final int minPayloadLength;

  const MavlinkMessageDef({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    required this.crcExtra,
    required this.minPayloadLength,
  });

  /// JSON에서 생성
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

  /// JSON으로 변환
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'fields': fields.map((f) => f.toJson()).toList(),
        'crcExtra': crcExtra,
        'minPayloadLength': minPayloadLength,
      };

  /// 필드 이름으로 필드 정의 찾기
  MavlinkFieldDef? getField(String fieldName) {
    for (final field in fields) {
      if (field.name == fieldName) return field;
    }
    return null;
  }

  @override
  String toString() => 'MavlinkMessageDef(id: $id, name: $name)';
}

/// MAVLink 필드 정의
///
/// MAVLink 메시지 내의 개별 필드 정의를 나타냅니다.
class MavlinkFieldDef {
  /// 필드 이름
  final String name;

  /// 필드 데이터 타입 (예: "uint8_t", "int16_t", "float", "char[16]")
  final String type;

  /// 배열 길이 (배열이 아니면 0)
  final int arrayLength;

  /// 필드 설명
  final String description;

  /// 단위 (예: "m/s", "deg", "mV")
  final String? units;

  /// 열거형 이름 (열거형 필드인 경우)
  final String? enumName;

  /// 페이로드 내 오프셋 (바이트)
  final int offset;

  /// 필드 크기 (바이트)
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

  /// JSON에서 생성
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

  /// JSON으로 변환
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

  /// 배열 필드인지 확인
  bool get isArray => arrayLength > 0;

  /// 기본 데이터 타입 반환 (배열 표기 제거)
  String get baseType {
    final bracketIndex = type.indexOf('[');
    return bracketIndex > 0 ? type.substring(0, bracketIndex) : type;
  }

  @override
  String toString() => 'MavlinkFieldDef(name: $name, type: $type)';
}

/// MAVLink 열거형 정의
class MavlinkEnumDef {
  /// 열거형 이름
  final String name;

  /// 열거형 설명
  final String description;

  /// 열거형 항목 목록
  final List<MavlinkEnumEntry> entries;

  /// 비트마스크 열거형인지 여부
  final bool isBitmask;

  const MavlinkEnumDef({
    required this.name,
    required this.description,
    required this.entries,
    this.isBitmask = false,
  });

  /// JSON에서 생성
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

  /// JSON으로 변환
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
        'isBitmask': isBitmask,
      };

  /// 값으로 항목 찾기
  MavlinkEnumEntry? getEntryByValue(int value) {
    for (final entry in entries) {
      if (entry.value == value) return entry;
    }
    return null;
  }
}

/// MAVLink 열거형 항목
class MavlinkEnumEntry {
  /// 항목 이름
  final String name;

  /// 항목 값
  final int value;

  /// 항목 설명
  final String description;

  const MavlinkEnumEntry({
    required this.name,
    required this.value,
    required this.description,
  });

  /// JSON에서 생성
  factory MavlinkEnumEntry.fromJson(Map<String, dynamic> json) {
    return MavlinkEnumEntry(
      name: json['name'] as String,
      value: json['value'] as int,
      description: json['description'] as String? ?? '',
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'description': description,
      };
}

/// MAVLink 메시지 규격 (전체)
///
/// XML 파일에서 파싱된 전체 메시지 규격을 나타냅니다.
class MavlinkSpec {
  /// MAVLink 버전
  final int version;

  /// 다이얼렉트 버전
  final int dialect;

  /// 메시지 정의 맵 (ID → MessageDef)
  final Map<int, MavlinkMessageDef> messages;

  /// 메시지 정의 맵 (이름 → MessageDef)
  final Map<String, MavlinkMessageDef> messagesByName;

  /// 열거형 정의 맵 (이름 → EnumDef)
  final Map<String, MavlinkEnumDef> enums;

  MavlinkSpec({
    required this.version,
    required this.dialect,
    required List<MavlinkMessageDef> messageList,
    required List<MavlinkEnumDef> enumList,
  })  : messages = {for (var m in messageList) m.id: m},
        messagesByName = {for (var m in messageList) m.name: m},
        enums = {for (var e in enumList) e.name: e};

  /// JSON에서 생성
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

  /// JSON으로 변환
  Map<String, dynamic> toJson() => {
        'version': version,
        'dialect': dialect,
        'messages': messages.values.map((m) => m.toJson()).toList(),
        'enums': enums.values.map((e) => e.toJson()).toList(),
      };

  /// 메시지 ID로 메시지 정의 찾기
  MavlinkMessageDef? getMessage(int id) => messages[id];

  /// 메시지 이름으로 메시지 정의 찾기
  MavlinkMessageDef? getMessageByName(String name) => messagesByName[name];

  /// 열거형 이름으로 열거형 정의 찾기
  MavlinkEnumDef? getEnum(String name) => enums[name];

  /// 지정된 메시지 이름만 포함하는 새 MavlinkSpec을 반환합니다.
  ///
  /// [messageNames]에 포함된 메시지만 필터링하고,
  /// 해당 메시지에서 참조하는 열거형만 포함합니다.
  MavlinkSpec filterByMessages(Set<String> messageNames) {
    // 필터링된 메시지 목록
    final filteredMessages = messages.values
        .where((m) => messageNames.contains(m.name))
        .toList();

    // 필터링된 메시지에서 참조하는 열거형 이름 수집
    final referencedEnums = <String>{};
    for (final message in filteredMessages) {
      for (final field in message.fields) {
        if (field.enumName != null) {
          referencedEnums.add(field.enumName!);
        }
      }
    }

    // 참조된 열거형만 포함
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
