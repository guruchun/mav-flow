import 'dart:typed_data';

/// MAVLink v2 프레임 구조
///
/// MAVLink v2 프로토콜의 바이너리 프레임을 나타냅니다.
///
/// 프레임 구조:
/// ```
/// +--------+--------+--------+--------+--------+--------+--------+--------+
/// | Magic  | Length | Incompat| Compat | Seq    | SysID  | CompID | MsgID  |
/// | 0xFD   | (1)    | Flags   | Flags  | (1)    | (1)    | (1)    | (3, LE)|
/// +--------+--------+--------+--------+--------+--------+--------+--------+
/// | Payload (0-255 bytes)                                                  |
/// +--------+--------+--------+--------+--------+--------+--------+--------+
/// | Checksum (CRC-16/MCRF4XX, 2 bytes, LE)                                |
/// +--------+--------+--------+--------+--------+--------+--------+--------+
/// | Signature (optional, 13 bytes)                                         |
/// +--------+--------+--------+--------+--------+--------+--------+--------+
/// ```
class MavlinkFrame {
  /// MAVLink 버전 식별자 (0xFD = v2, 0xFE = v1)
  final int magic;

  /// 페이로드 길이 (0-255 바이트)
  final int payloadLength;

  /// 비호환 플래그 (현재 0x01 = 서명 있음)
  final int incompatFlags;

  /// 호환 플래그 (예약됨)
  final int compatFlags;

  /// 시퀀스 번호 (0-255, 롤오버)
  final int sequence;

  /// 시스템 ID (1-255, 송신자 시스템)
  final int systemId;

  /// 컴포넌트 ID (0-255, 송신자 컴포넌트)
  final int componentId;

  /// 메시지 ID (24-bit, Little Endian)
  final int messageId;

  /// 페이로드 데이터
  final Uint8List payload;

  /// 체크섬 (CRC-16/MCRF4XX, Little Endian)
  final int checksum;

  /// 서명 (옵션, 13 바이트)
  final Uint8List? signature;

  /// 원본 바이트 데이터 (디버깅용)
  final Uint8List rawBytes;

  const MavlinkFrame({
    required this.magic,
    required this.payloadLength,
    required this.incompatFlags,
    required this.compatFlags,
    required this.sequence,
    required this.systemId,
    required this.componentId,
    required this.messageId,
    required this.payload,
    required this.checksum,
    this.signature,
    required this.rawBytes,
  });

  /// MAVLink v2 프레임인지 확인
  bool get isV2 => magic == 0xFD;

  /// MAVLink v1 프레임인지 확인
  bool get isV1 => magic == 0xFE;

  /// 서명이 포함된 프레임인지 확인
  bool get hasSignature => (incompatFlags & 0x01) != 0;

  /// 헤더 크기 (v2: 10 바이트, v1: 6 바이트)
  int get headerSize => isV2 ? 10 : 6;

  /// 전체 프레임 크기
  int get frameSize =>
      headerSize + payloadLength + 2 + (hasSignature ? 13 : 0);

  @override
  String toString() =>
      'MavlinkFrame(msgId: $messageId, sys: $systemId, comp: $componentId, len: $payloadLength)';
}

/// MAVLink 프레임 상수
class MavlinkConstants {
  /// MAVLink v2 매직 바이트
  static const int v2Magic = 0xFD;

  /// MAVLink v1 매직 바이트
  static const int v1Magic = 0xFE;

  /// MAVLink v2 헤더 크기 (바이트)
  static const int v2HeaderSize = 10;

  /// MAVLink v1 헤더 크기 (바이트)
  static const int v1HeaderSize = 6;

  /// 체크섬 크기 (바이트)
  static const int checksumSize = 2;

  /// 서명 크기 (바이트)
  static const int signatureSize = 13;

  /// 최대 페이로드 크기 (바이트)
  static const int maxPayloadSize = 255;

  /// 비호환 플래그: 서명 있음
  static const int incompatFlagSigned = 0x01;
}
