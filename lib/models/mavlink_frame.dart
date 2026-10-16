import 'dart:typed_data';

/// MAVLink v2 frame structure
///
/// Represents a binary frame of MAVLink v2 protocol.
///
/// Frame structure:
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
  /// MAVLink version identifier (0xFD = v2, 0xFE = v1)
  final int magic;

  /// Payload length (0-255 bytes)
  final int payloadLength;

  /// Incompatible flags (currently 0x01 = signed)
  final int incompatFlags;

  /// Compatible flags (reserved)
  final int compatFlags;

  /// Sequence number (0-255, rollover)
  final int sequence;

  /// System ID (1-255, sender system)
  final int systemId;

  /// Component ID (0-255, sender component)
  final int componentId;

  /// Message ID (24-bit, Little Endian)
  final int messageId;

  /// Payload data
  final Uint8List payload;

  /// Checksum (CRC-16/MCRF4XX, Little Endian)
  final int checksum;

  /// Signature (optional, 13 bytes)
  final Uint8List? signature;

  /// Raw byte data (for debugging)
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

  /// Checks if this is a MAVLink v2 frame
  bool get isV2 => magic == 0xFD;

  /// Checks if this is a MAVLink v1 frame
  bool get isV1 => magic == 0xFE;

  /// Checks if this frame includes a signature
  bool get hasSignature => (incompatFlags & 0x01) != 0;

  /// Header size (v2: 10 bytes, v1: 6 bytes)
  int get headerSize => isV2 ? 10 : 6;

  /// Total frame size
  int get frameSize =>
      headerSize + payloadLength + 2 + (hasSignature ? 13 : 0);

  @override
  String toString() =>
      'MavlinkFrame(msgId: $messageId, sys: $systemId, comp: $componentId, len: $payloadLength)';
}

/// MAVLink frame constants
class MavlinkConstants {
  /// MAVLink v2 magic byte
  static const int v2Magic = 0xFD;

  /// MAVLink v1 magic byte
  static const int v1Magic = 0xFE;

  /// MAVLink v2 header size (bytes)
  static const int v2HeaderSize = 10;

  /// MAVLink v1 header size (bytes)
  static const int v1HeaderSize = 6;

  /// Checksum size (bytes)
  static const int checksumSize = 2;

  /// Signature size (bytes)
  static const int signatureSize = 13;

  /// Maximum payload size (bytes)
  static const int maxPayloadSize = 255;

  /// Incompatible flag: signed
  static const int incompatFlagSigned = 0x01;
}
