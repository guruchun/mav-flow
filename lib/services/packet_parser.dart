import 'dart:typed_data';
import '../models/field_value.dart';

// ─── CRC8 계산기 ────────────────────────────────────────────────────────────

/// CRC8 polynomial table 기반 체크섬 계산기.
///
/// Python CRC8Calculator에 대응한다.
/// polynomial=0x07, initial_value=0x00 (CRC-8/SMBUS)
class Crc8Calculator {
  final int polynomial;
  final int initialValue;
  late final List<int> _table;

  Crc8Calculator({this.polynomial = 0x07, this.initialValue = 0x00}) {
    _table = _buildTable(polynomial);
  }

  static List<int> _buildTable(int polynomial) {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int inner = 0; inner < 8; inner++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// 바이트 시퀀스에 대한 CRC8 체크섬을 계산한다.
  int calculate(Uint8List data) {
    int crc = initialValue;
    for (final byte in data) {
      crc = _table[crc ^ byte];
    }
    return crc;
  }
}

// ─── 패킷 파서 ───────────────────────────────────────────────────────────────

/// YAML 규격 기반 패킷 프레임 검증 및 페이로드 파싱.
///
/// Frame structure: [header(1)] + [payload(N)] + [crc8(1)] + [tail(1)]
/// Python PacketParser에 대응한다.
class PacketParser {
  final Map<String, dynamic> spec;
  late final Crc8Calculator _crc;

  PacketParser(this.spec) {
    final poly = spec['packet']['crc8_polynomial'] as int;
    _crc = Crc8Calculator(polynomial: poly);
  }

  /// 패킷 프레임의 Header, Tail, CRC8을 검증한다.
  bool validateFrame(Uint8List rawPacket) {
    if (rawPacket.length < 3) return false;

    final expectedHeader = spec['packet']['header'] as int;
    final expectedTail = spec['packet']['tail'] as int;

    if (rawPacket[0] != expectedHeader) return false;
    if (rawPacket[rawPacket.length - 1] != expectedTail) return false;

    // CRC8: payload = rawPacket[1..-3], receivedCrc = rawPacket[-2]
    final payload = Uint8List.sublistView(rawPacket, 1, rawPacket.length - 2);
    final receivedCrc = rawPacket[rawPacket.length - 2];
    final calculatedCrc = _crc.calculate(payload);

    return calculatedCrc == receivedCrc;
  }

  /// Big-Endian 바이트를 타입에 맞게 변환하고 DMI 오프셋/스케일을 적용한다.
  ///
  /// Returns (rawValue, convertedValue)
  static (int, double) decodeField(
    Uint8List rawBytes,
    String dataType,
    int dmiOffset,
    double scaleFactor,
  ) {
    final bd = ByteData.sublistView(rawBytes);
    int rawValue;

    switch (dataType) {
      case 'uint8':
        rawValue = bd.getUint8(0);
      case 'int16':
        rawValue = bd.getInt16(0, Endian.big);
      case 'uint16':
        rawValue = bd.getUint16(0, Endian.big);
      case 'int32':
        rawValue = bd.getInt32(0, Endian.big);
      case 'uint32':
        rawValue = bd.getUint32(0, Endian.big);
      default:
        rawValue = 0;
    }

    final convertedValue = (rawValue - dmiOffset) * scaleFactor;
    return (rawValue, convertedValue);
  }

  /// 페이로드를 Base/FuelCell/Cells 영역으로 분리 후 각 필드를 파싱한다.
  ///
  /// Python parse_payload()에 대응한다.
  List<FieldValue> parsePayload(Uint8List payload) {
    final results = <FieldValue>[];
    final messages = spec['messages'] as Map<String, dynamic>;

    for (final msgEntry in messages.entries) {
      final msgName = msgEntry.key;
      final msgInfo = msgEntry.value as Map<String, dynamic>;
      final msgOffset = msgInfo['offset'] as int;
      final groups = msgInfo['groups'] as Map<String, dynamic>;

      for (final groupEntry in groups.entries) {
        final groupName = groupEntry.key;
        final groupInfo = groupEntry.value as Map<String, dynamic>;
        final fields = groupInfo['fields'] as List<dynamic>;

        for (final fieldDef in fields) {
          final field = fieldDef as Map<String, dynamic>;
          final fieldName = field['name'] as String;
          final dataType = field['type'] as String;
          final byteSize = field['byte_size'] as int;
          final byteOffset = field['byte_offset'] as int;
          final dmiOffset = field['dmi_offset'] as int;
          final scaleFactor = (field['scale_factor'] as num).toDouble();

          if (dataType.endsWith('_array')) {
            // 배열 필드 처리 (e.g., int16_array)
            final baseType = dataType.replaceAll('_array', '');
            final count = field['count'] as int;
            final elementSize = byteSize ~/ count;

            for (int i = 0; i < count; i++) {
              final elementOffset = msgOffset + byteOffset + (i * elementSize);
              if (elementOffset + elementSize > payload.length) continue;
              final elementBytes = Uint8List.sublistView(
                  payload, elementOffset, elementOffset + elementSize);
              final (raw, converted) =
                  decodeField(elementBytes, baseType, dmiOffset, scaleFactor);
              results.add(FieldValue(
                name: '$fieldName[$i]',
                messageType: msgName,
                group: groupName,
                rawValue: raw,
                convertedValue: converted,
                dataType: baseType,
                scaleFactor: scaleFactor,
                dmiOffset: dmiOffset,
              ));
            }
          } else {
            // 일반 필드 처리
            final fieldStart = msgOffset + byteOffset;
            if (fieldStart + byteSize > payload.length) continue;
            final fieldBytes = Uint8List.sublistView(
                payload, fieldStart, fieldStart + byteSize);
            final (raw, converted) =
                decodeField(fieldBytes, dataType, dmiOffset, scaleFactor);
            results.add(FieldValue(
              name: fieldName,
              messageType: msgName,
              group: groupName,
              rawValue: raw,
              convertedValue: converted,
              dataType: dataType,
              scaleFactor: scaleFactor,
              dmiOffset: dmiOffset,
            ));
          }
        }
      }
    }

    return results;
  }
}
