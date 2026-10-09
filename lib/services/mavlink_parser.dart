import 'dart:typed_data';

import '../models/mavlink_frame.dart';
import '../models/mavlink_message_def.dart';

/// MAVLink v2 메시지 파서
///
/// 바이트 스트림에서 MAVLink 프레임을 추출하고 페이로드를 파싱합니다.
class MavlinkParser {
  /// 메시지 규격
  final MavlinkSpec spec;

  /// 불완전한 데이터 버퍼
  final List<int> _buffer = [];

  /// 파싱 통계
  int _validFrames = 0;
  int _crcErrors = 0;
  int _unknownMessages = 0;

  MavlinkParser(this.spec);

  /// 유효한 프레임 수
  int get validFrames => _validFrames;

  /// CRC 오류 수
  int get crcErrors => _crcErrors;

  /// 알 수 없는 메시지 수
  int get unknownMessages => _unknownMessages;

  /// 통계 초기화
  void resetStats() {
    _validFrames = 0;
    _crcErrors = 0;
    _unknownMessages = 0;
  }

  /// 바이트 스트림에서 완전한 MAVLink 프레임을 추출합니다.
  ///
  /// 불완전한 데이터는 내부 버퍼에 유지되어 다음 호출 시 결합됩니다.
  List<MavlinkFrame> extractFrames(Uint8List data) {
    _buffer.addAll(data);
    final frames = <MavlinkFrame>[];

    while (_buffer.isNotEmpty) {
      // 매직 바이트 찾기
      final magicIndex = _findMagicByte();
      if (magicIndex < 0) {
        _buffer.clear();
        break;
      }

      // 매직 바이트 앞의 데이터 버리기
      if (magicIndex > 0) {
        _buffer.removeRange(0, magicIndex);
      }

      // 최소 헤더 크기 확인
      if (_buffer.length < MavlinkConstants.v2HeaderSize) {
        break; // 더 많은 데이터 필요
      }

      final magic = _buffer[0];
      final isV2 = magic == MavlinkConstants.v2Magic;

      if (!isV2) {
        // v1은 현재 지원하지 않음, 다음 바이트로 이동
        _buffer.removeAt(0);
        continue;
      }

      final payloadLength = _buffer[1];
      final incompatFlags = _buffer[2];
      final hasSignature = (incompatFlags & MavlinkConstants.incompatFlagSigned) != 0;

      // 전체 프레임 크기 계산
      final frameSize = MavlinkConstants.v2HeaderSize +
          payloadLength +
          MavlinkConstants.checksumSize +
          (hasSignature ? MavlinkConstants.signatureSize : 0);

      // 완전한 프레임인지 확인
      if (_buffer.length < frameSize) {
        break; // 더 많은 데이터 필요
      }

      // 프레임 추출
      final frameBytes = Uint8List.fromList(_buffer.sublist(0, frameSize));
      _buffer.removeRange(0, frameSize);

      // 프레임 파싱
      final frame = _parseFrame(frameBytes);
      if (frame != null) {
        frames.add(frame);
      }
    }

    return frames;
  }

  /// 버퍼에서 MAVLink 매직 바이트를 찾습니다.
  int _findMagicByte() {
    for (int i = 0; i < _buffer.length; i++) {
      if (_buffer[i] == MavlinkConstants.v2Magic ||
          _buffer[i] == MavlinkConstants.v1Magic) {
        return i;
      }
    }
    return -1;
  }

  /// 바이트 배열에서 MAVLink 프레임을 파싱합니다.
  MavlinkFrame? _parseFrame(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);

    final magic = bd.getUint8(0);
    final payloadLength = bd.getUint8(1);
    final incompatFlags = bd.getUint8(2);
    final compatFlags = bd.getUint8(3);
    final sequence = bd.getUint8(4);
    final systemId = bd.getUint8(5);
    final componentId = bd.getUint8(6);

    // 24-bit 메시지 ID (Little Endian)
    final messageId = bd.getUint8(7) |
        (bd.getUint8(8) << 8) |
        (bd.getUint8(9) << 16);

    // 페이로드
    final payloadStart = MavlinkConstants.v2HeaderSize;
    final payload = bytes.sublist(payloadStart, payloadStart + payloadLength);

    // 체크섬 (Little Endian)
    final checksumOffset = payloadStart + payloadLength;
    final checksum = bd.getUint16(checksumOffset, Endian.little);

    // 서명 (옵션)
    Uint8List? signature;
    if ((incompatFlags & MavlinkConstants.incompatFlagSigned) != 0) {
      final sigOffset = checksumOffset + MavlinkConstants.checksumSize;
      signature = bytes.sublist(sigOffset, sigOffset + MavlinkConstants.signatureSize);
    }

    final frame = MavlinkFrame(
      magic: magic,
      payloadLength: payloadLength,
      incompatFlags: incompatFlags,
      compatFlags: compatFlags,
      sequence: sequence,
      systemId: systemId,
      componentId: componentId,
      messageId: messageId,
      payload: Uint8List.fromList(payload),
      checksum: checksum,
      signature: signature,
      rawBytes: bytes,
    );

    // CRC 검증
    if (!validateCrc(frame)) {
      _crcErrors++;
      return null;
    }

    _validFrames++;
    return frame;
  }

  /// MAVLink 프레임의 CRC를 검증합니다.
  bool validateCrc(MavlinkFrame frame) {
    final messageDef = spec.getMessage(frame.messageId);
    if (messageDef == null) {
      _unknownMessages++;
      // 알 수 없는 메시지는 CRC 검증 불가, 일단 통과
      return true;
    }

    final calculatedCrc = calculateCrc(frame, messageDef.crcExtra);
    return calculatedCrc == frame.checksum;
  }

  /// CRC-16/MCRF4XX를 계산합니다.
  int calculateCrc(MavlinkFrame frame, int crcExtra) {
    int crc = 0xFFFF;

    // 헤더 (magic 제외, 1~9 바이트)
    for (int i = 1; i < MavlinkConstants.v2HeaderSize; i++) {
      crc = _crcAccumulate(frame.rawBytes[i], crc);
    }

    // 페이로드
    for (final byte in frame.payload) {
      crc = _crcAccumulate(byte, crc);
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

  /// 페이로드를 파싱하여 필드 값 맵을 반환합니다.
  ///
  /// 키는 "{MessageName}.{FieldName}" 형식의 TAG입니다.
  Map<String, dynamic> parsePayload(MavlinkFrame frame) {
    final messageDef = spec.getMessage(frame.messageId);
    if (messageDef == null) {
      return {};
    }

    final result = <String, dynamic>{};
    final bd = ByteData.sublistView(frame.payload);

    for (final field in messageDef.fields) {
      final tag = '${messageDef.name}.${field.name}';

      try {
        final value = _readFieldValue(bd, field);
        result[tag] = value;
      } catch (e) {
        // 필드 읽기 실패 시 기본값
        result[tag] = null;
      }
    }

    return result;
  }

  /// 필드 값을 읽습니다.
  dynamic _readFieldValue(ByteData bd, MavlinkFieldDef field) {
    if (field.offset >= bd.lengthInBytes) {
      return null;
    }

    if (field.isArray) {
      return _readArrayField(bd, field);
    }

    return _readScalarField(bd, field);
  }

  /// 스칼라 필드 값을 읽습니다.
  dynamic _readScalarField(ByteData bd, MavlinkFieldDef field) {
    final offset = field.offset;

    if (offset + _getTypeSize(field.baseType) > bd.lengthInBytes) {
      return null;
    }

    switch (field.baseType) {
      case 'int8_t':
        return bd.getInt8(offset);
      case 'uint8_t':
      case 'char':
        return bd.getUint8(offset);
      case 'int16_t':
        return bd.getInt16(offset, Endian.little);
      case 'uint16_t':
        return bd.getUint16(offset, Endian.little);
      case 'int32_t':
        return bd.getInt32(offset, Endian.little);
      case 'uint32_t':
        return bd.getUint32(offset, Endian.little);
      case 'int64_t':
        return bd.getInt64(offset, Endian.little);
      case 'uint64_t':
        return bd.getUint64(offset, Endian.little);
      case 'float':
        return bd.getFloat32(offset, Endian.little);
      case 'double':
        return bd.getFloat64(offset, Endian.little);
      default:
        return bd.getUint8(offset);
    }
  }

  /// 배열 필드 값을 읽습니다.
  dynamic _readArrayField(ByteData bd, MavlinkFieldDef field) {
    final baseType = field.baseType;

    // char 배열은 문자열로 변환
    if (baseType == 'char') {
      final bytes = <int>[];
      for (int i = 0; i < field.arrayLength; i++) {
        final offset = field.offset + i;
        if (offset >= bd.lengthInBytes) break;
        final byte = bd.getUint8(offset);
        if (byte == 0) break; // null terminator
        bytes.add(byte);
      }
      return String.fromCharCodes(bytes);
    }

    // 숫자 배열
    final values = <num>[];
    final unitSize = _getTypeSize(baseType);

    for (int i = 0; i < field.arrayLength; i++) {
      final offset = field.offset + (i * unitSize);
      if (offset + unitSize > bd.lengthInBytes) break;

      final value = _readValueAtOffset(bd, offset, baseType);
      if (value != null) {
        values.add(value);
      }
    }

    return values;
  }

  /// 지정된 오프셋에서 값을 읽습니다.
  num? _readValueAtOffset(ByteData bd, int offset, String type) {
    switch (type) {
      case 'int8_t':
        return bd.getInt8(offset);
      case 'uint8_t':
        return bd.getUint8(offset);
      case 'int16_t':
        return bd.getInt16(offset, Endian.little);
      case 'uint16_t':
        return bd.getUint16(offset, Endian.little);
      case 'int32_t':
        return bd.getInt32(offset, Endian.little);
      case 'uint32_t':
        return bd.getUint32(offset, Endian.little);
      case 'int64_t':
        return bd.getInt64(offset, Endian.little);
      case 'uint64_t':
        return bd.getUint64(offset, Endian.little);
      case 'float':
        return bd.getFloat32(offset, Endian.little);
      case 'double':
        return bd.getFloat64(offset, Endian.little);
      default:
        return null;
    }
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

  /// 버퍼를 비웁니다.
  void clearBuffer() {
    _buffer.clear();
  }
}
