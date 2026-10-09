import 'dart:convert';
import 'dart:io';

/// Data Table의 각 필드 항목
///
/// 현재값(수신된 값)과 전송값(사용자 수정 값)을 분리하여 관리합니다.
class DataTableEntry {
  /// TAG - "{MessageName}.{FieldName}" 형식
  final String tag;

  /// 메시지 이름
  final String messageName;

  /// 필드 이름
  final String fieldName;

  /// 데이터 타입 (예: "uint8_t", "int16_t", "float")
  final String dataType;

  /// 단위 (예: "m/s", "deg", "mV")
  final String? units;

  /// 필드 설명
  final String description;

  /// 열거형 이름 (열거형 필드인 경우)
  final String? enumName;

  /// 배열 길이 (배열이 아니면 0)
  final int arrayLength;

  /// 현재값 (수신된 값) - 읽기 전용
  dynamic currentValue;

  /// 전송값 (사용자 수정 가능)
  dynamic sendValue;

  /// 마지막 수신 시간
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

  /// TAG를 생성합니다.
  static String createTag(String messageName, String fieldName) {
    return '$messageName.$fieldName';
  }

  /// TAG에서 메시지 이름을 추출합니다.
  static String? getMessageNameFromTag(String tag) {
    final parts = tag.split('.');
    return parts.isNotEmpty ? parts[0] : null;
  }

  /// TAG에서 필드 이름을 추출합니다.
  static String? getFieldNameFromTag(String tag) {
    final parts = tag.split('.');
    return parts.length > 1 ? parts.sublist(1).join('.') : null;
  }

  /// 배열 필드인지 확인
  bool get isArray => arrayLength > 0;

  /// 현재값을 문자열로 반환
  String get currentValueString => _valueToString(currentValue);

  /// 전송값을 문자열로 반환
  String get sendValueString => _valueToString(sendValue);

  /// 값을 문자열로 변환
  String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    if (value is double) {
      // 소수점 6자리까지 표시
      return value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return value.toString();
  }

  /// 현재값을 전송값으로 복사
  void copyCurrentToSend() {
    if (currentValue is List) {
      sendValue = List.from(currentValue as List);
    } else {
      sendValue = currentValue;
    }
  }

  /// 기본 데이터 타입 반환 (배열 표기 제거)
  String get baseType {
    final bracketIndex = dataType.indexOf('[');
    return bracketIndex > 0 ? dataType.substring(0, bracketIndex) : dataType;
  }

  @override
  String toString() =>
      'DataTableEntry(tag: $tag, current: $currentValue, send: $sendValue)';
}

/// Data Table 전체 관리
class DataTable {
  /// 모든 항목 (TAG → Entry)
  final Map<String, DataTableEntry> entries = {};

  /// 메시지별 항목 목록 (MessageName → List<Entry>)
  final Map<String, List<DataTableEntry>> _entriesByMessage = {};

  /// 항목 추가
  void addEntry(DataTableEntry entry) {
    entries[entry.tag] = entry;
    _entriesByMessage.putIfAbsent(entry.messageName, () => []).add(entry);
  }

  /// 항목 가져오기
  DataTableEntry? getEntry(String tag) => entries[tag];

  /// 메시지별 항목 목록 가져오기
  List<DataTableEntry> getEntriesByMessage(String messageName) {
    return _entriesByMessage[messageName] ?? [];
  }

  /// 모든 메시지 이름 목록
  List<String> get messageNames => _entriesByMessage.keys.toList();

  /// 현재값 업데이트 (수신 메시지용)
  void updateCurrentValue(String tag, dynamic value) {
    final entry = entries[tag];
    if (entry != null) {
      entry.currentValue = value;
      entry.lastUpdated = DateTime.now();
    }
  }

  /// 전송값 업데이트 (사용자 입력용)
  void updateSendValue(String tag, dynamic value) {
    final entry = entries[tag];
    if (entry != null) {
      entry.sendValue = value;
    }
  }

  /// 메시지의 모든 필드에 대해 현재값을 전송값으로 복사
  void copyCurrentToSendForMessage(String messageName) {
    final messageEntries = _entriesByMessage[messageName];
    if (messageEntries != null) {
      for (final entry in messageEntries) {
        entry.copyCurrentToSend();
      }
    }
  }

  /// 메시지의 전송값들을 Map으로 반환
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

  /// 전체 초기화
  void clear() {
    entries.clear();
    _entriesByMessage.clear();
  }

  /// 항목 수
  int get length => entries.length;

  /// 모든 항목 목록
  List<DataTableEntry> get allEntries => entries.values.toList();

  /// 전송값을 JSON 파일로 저장합니다.
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

  /// JSON 파일에서 전송값을 로드합니다.
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
