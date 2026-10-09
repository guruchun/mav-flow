import 'dart:typed_data';

import '../models/mavlink_frame.dart';
import '../models/mavlink_message_def.dart';

/// MAVLink 메시지 직렬화/역직렬화 코덱
///
/// 메시지 필드 값을 MAVLink v2 바이너리 형식으로 직렬화합니다.
class MavlinkCodec {
  /// 메시지 규격
  final MavlinkSpec spec;

  MavlinkCodec(this.spec);

  /// 필드 값 맵을 MAVLink v2 바이너리 메시지로 직렬화합니다.
  ///
  /// [messageId]는 메시지 ID입니다.
  /// [systemId]는 송신자 시스템 ID입니다.
  /// [componentId]는 송신자 컴포넌트 ID입니다.
  /// [sequence]는 시퀀스 번호입니다 (0-255).
  /// [fieldValues]는 필드 이름과 값의 맵입니다.
  Uint8List encode({
    required int messageId,
    required int systemId,
    required int componentId,
    required int sequence,
    required Map<String, dynamic> fieldValues,
  }) {
    final messageDef = spec.getMessage(messageId);
    if (messageDef == null) {
      throw ArgumentError('알 수 없는 메시지 ID: $messageId');
    }

    // 페이로드 생성
    final payload = _encodePayload(messageDef, fieldValues);

    // 프레임 구성
    final frameSize = MavlinkConstants.v2HeaderSize +
        payload.length +
        MavlinkConstants.checksumSize;
    final frame = Uint8List(frameSize);
    final bd = ByteData.sublistView(frame);

    // 헤더
    bd.setUint8(0, MavlinkConstants.v2Magic);
    bd.setUint8(1, payload.length);
    bd.setUint8(2, 0); // incompatFlags
    bd.setUint8(3, 0); // compatFlags
    bd.setUint8(4, sequence & 0xFF);
    bd.setUint8(5, systemId);
    bd.setUint8(6, componentId);

    // 24-bit 메시지 ID (Little Endian)
    bd.setUint8(7, messageId & 0xFF);
    bd.setUint8(8, (messageId >> 8) & 0xFF);
    bd.setUint8(9, (messageId >> 16) & 0xFF);

    // 페이로드 복사
    frame.setRange(MavlinkConstants.v2HeaderSize,
        MavlinkConstants.v2HeaderSize + payload.length, payload);

    // CRC 계산 및 추가
    final crc = _calculateCrc(frame, payload.length, messageDef.crcExtra);
    final checksumOffset = MavlinkConstants.v2HeaderSize + payload.length;
    bd.setUint16(checksumOffset, crc, Endian.little);

    return frame;
  }

  /// 메시지 이름으로 인코딩합니다.
  Uint8List encodeByName({
    required String messageName,
    required int systemId,
    required int componentId,
    required int sequence,
    required Map<String, dynamic> fieldValues,
  }) {
    final messageDef = spec.getMessageByName(messageName);
    if (messageDef == null) {
      throw ArgumentError('알 수 없는 메시지 이름: $messageName');
    }

    return encode(
      messageId: messageDef.id,
      systemId: systemId,
      componentId: componentId,
      sequence: sequence,
      fieldValues: fieldValues,
    );
  }

  /// 페이로드를 인코딩합니다.
  Uint8List _encodePayload(
      MavlinkMessageDef messageDef, Map<String, dynamic> fieldValues) {
    final payload = Uint8List(messageDef.minPayloadLength);
    final bd = ByteData.sublistView(payload);

    for (final field in messageDef.fields) {
      final value = fieldValues[field.name];
      if (value == null) continue;

      try {
        _writeFieldValue(bd, field, value);
      } catch (e) {
        // 필드 쓰기 실패 시 무시 (기본값 0 유지)
      }
    }

    // 후행 0 제거 (MAVLink truncation)
    int truncatedLength = payload.length;
    while (truncatedLength > 0 && payload[truncatedLength - 1] == 0) {
      truncatedLength--;
    }

    // 최소 1바이트는 유지
    if (truncatedLength == 0 && payload.isNotEmpty) {
      truncatedLength = 1;
    }

    return payload.sublist(0, truncatedLength);
  }

  /// 필드 값을 씁니다.
  void _writeFieldValue(ByteData bd, MavlinkFieldDef field, dynamic value) {
    if (field.isArray) {
      _writeArrayField(bd, field, value);
    } else {
      _writeScalarField(bd, field, value);
    }
  }

  /// 스칼라 필드 값을 씁니다.
  void _writeScalarField(ByteData bd, MavlinkFieldDef field, dynamic value) {
    final offset = field.offset;
    final numValue = (value is num) ? value : 0;

    switch (field.baseType) {
      case 'int8_t':
        bd.setInt8(offset, numValue.toInt());
        break;
      case 'uint8_t':
      case 'char':
        bd.setUint8(offset, numValue.toInt());
        break;
      case 'int16_t':
        bd.setInt16(offset, numValue.toInt(), Endian.little);
        break;
      case 'uint16_t':
        bd.setUint16(offset, numValue.toInt(), Endian.little);
        break;
      case 'int32_t':
        bd.setInt32(offset, numValue.toInt(), Endian.little);
        break;
      case 'uint32_t':
        bd.setUint32(offset, numValue.toInt(), Endian.little);
        break;
      case 'int64_t':
        bd.setInt64(offset, numValue.toInt(), Endian.little);
        break;
      case 'uint64_t':
        bd.setUint64(offset, numValue.toInt(), Endian.little);
        break;
      case 'float':
        bd.setFloat32(offset, numValue.toDouble(), Endian.little);
        break;
      case 'double':
        bd.setFloat64(offset, numValue.toDouble(), Endian.little);
        break;
    }
  }

  /// 배열 필드 값을 씁니다.
  void _writeArrayField(ByteData bd, MavlinkFieldDef field, dynamic value) {
    final baseType = field.baseType;

    // char 배열 (문자열)
    if (baseType == 'char' && value is String) {
      final bytes = value.codeUnits;
      for (int i = 0; i < field.arrayLength && i < bytes.length; i++) {
        bd.setUint8(field.offset + i, bytes[i]);
      }
      return;
    }

    // 숫자 배열
    if (value is List) {
      final unitSize = _getTypeSize(baseType);
      for (int i = 0; i < field.arrayLength && i < value.length; i++) {
        final offset = field.offset + (i * unitSize);
        _writeValueAtOffset(bd, offset, baseType, value[i]);
      }
    }
  }

  /// 지정된 오프셋에 값을 씁니다.
  void _writeValueAtOffset(ByteData bd, int offset, String type, dynamic value) {
    final numValue = (value is num) ? value : 0;

    switch (type) {
      case 'int8_t':
        bd.setInt8(offset, numValue.toInt());
        break;
      case 'uint8_t':
        bd.setUint8(offset, numValue.toInt());
        break;
      case 'int16_t':
        bd.setInt16(offset, numValue.toInt(), Endian.little);
        break;
      case 'uint16_t':
        bd.setUint16(offset, numValue.toInt(), Endian.little);
        break;
      case 'int32_t':
        bd.setInt32(offset, numValue.toInt(), Endian.little);
        break;
      case 'uint32_t':
        bd.setUint32(offset, numValue.toInt(), Endian.little);
        break;
      case 'int64_t':
        bd.setInt64(offset, numValue.toInt(), Endian.little);
        break;
      case 'uint64_t':
        bd.setUint64(offset, numValue.toInt(), Endian.little);
        break;
      case 'float':
        bd.setFloat32(offset, numValue.toDouble(), Endian.little);
        break;
      case 'double':
        bd.setFloat64(offset, numValue.toDouble(), Endian.little);
        break;
    }
  }

  /// CRC-16/MCRF4XX를 계산합니다.
  int _calculateCrc(Uint8List frame, int payloadLength, int crcExtra) {
    int crc = 0xFFFF;

    // 헤더 (magic 제외, 1~9 바이트)
    for (int i = 1; i < MavlinkConstants.v2HeaderSize; i++) {
      crc = _crcAccumulate(frame[i], crc);
    }

    // 페이로드
    for (int i = 0; i < payloadLength; i++) {
      crc = _crcAccumulate(frame[MavlinkConstants.v2HeaderSize + i], crc);
    }

    // CRC Extra
    crc = _crcAccumulate(crcExtra, crc);

    return crc;
  }

  /// CRC-16/MCRF4XX 누적 계산
  int _crcAccumulate(int byte, int crc) {
    final tmp = byte ^ (crc & 0xFF);
    final tmp2 = tmp ^ ((tmp << 4) & 0xFF);
    return ((crc >> 8) ^ (tmp2 << 8) ^ (tmp2 << 3) ^ (tmp2 >> 4)) & 0xFFFF;
  }

  /// 타입 크기를 반환합니다.
  int _getTypeSize(String type) {
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
}
