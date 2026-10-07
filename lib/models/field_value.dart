/// 패킷에서 파싱된 필드 하나의 결과를 담는 데이터 클래스.
///
/// Python의 FieldValue dataclass에 대응한다.
class FieldValue {
  final String name;
  final String messageType; // "Base", "FuelCell", "Cells"
  final String group; // "Stack", "Battery", "Pcu", etc.
  final int rawValue;
  final double convertedValue;
  final String dataType;
  final double scaleFactor;
  final int dmiOffset;

  const FieldValue({
    required this.name,
    required this.messageType,
    required this.group,
    required this.rawValue,
    required this.convertedValue,
    required this.dataType,
    required this.scaleFactor,
    required this.dmiOffset,
  });
}

/// 테이블에 표시할 행 데이터 (필터링 및 실시간 갱신용).
class FieldRow {
  final String name;
  final String messageType;
  final String dataType;
  final String scale;
  final String offset;

  String raw;
  String converted;

  FieldRow({
    required this.name,
    required this.messageType,
    required this.dataType,
    required this.scale,
    required this.offset,
    this.raw = '-',
    this.converted = '-',
  });
}
