import 'dart:typed_data';

import '../models/mavlink_frame.dart';
import '../models/mavlink_message_def.dart';

/// MAVLink v2 message parser
///
/// Extracts MAVLink frames from byte stream and parses payload.
class MavlinkParser {
  /// Message specification
  final MavlinkSpec spec;

  /// Incomplete data buffer
  final List<int> _buffer = [];

  /// Parsing statistics
  int _validFrames = 0;
  int _crcErrors = 0;
  int _unknownMessages = 0;

  MavlinkParser(this.spec);

  /// Valid frame count
  int get validFrames => _validFrames;

  /// CRC error count
  int get crcErrors => _crcErrors;

  /// Unknown message count
  int get unknownMessages => _unknownMessages;

  /// Resets statistics
  void resetStats() {
    _validFrames = 0;
    _crcErrors = 0;
    _unknownMessages = 0;
  }

  /// Extracts complete MAVLink frames from byte stream.
  ///
  /// Incomplete data is kept in internal buffer and combined on next call.
  List<MavlinkFrame> extractFrames(Uint8List data) {
    _buffer.addAll(data);
    final frames = <MavlinkFrame>[];

    while (_buffer.isNotEmpty) {
      // Find magic byte
      final magicIndex = _findMagicByte();
      if (magicIndex < 0) {
        _buffer.clear();
        break;
      }

      // Discard data before magic byte
      if (magicIndex > 0) {
        _buffer.removeRange(0, magicIndex);
      }

      // Check minimum header size
      if (_buffer.length < MavlinkConstants.v2HeaderSize) {
        break; // Need more data
      }

      final magic = _buffer[0];
      final isV2 = magic == MavlinkConstants.v2Magic;

      if (!isV2) {
        // v1 not currently supported, move to next byte
        _buffer.removeAt(0);
        continue;
      }

      final payloadLength = _buffer[1];
      final incompatFlags = _buffer[2];
      final hasSignature = (incompatFlags & MavlinkConstants.incompatFlagSigned) != 0;

      // Calculate total frame size
      final frameSize = MavlinkConstants.v2HeaderSize +
          payloadLength +
          MavlinkConstants.checksumSize +
          (hasSignature ? MavlinkConstants.signatureSize : 0);

      // Check if complete frame
      if (_buffer.length < frameSize) {
        break; // Need more data
      }

      // Extract frame
      final frameBytes = Uint8List.fromList(_buffer.sublist(0, frameSize));
      _buffer.removeRange(0, frameSize);

      // Parse frame
      final frame = _parseFrame(frameBytes);
      if (frame != null) {
        frames.add(frame);
      }
    }

    return frames;
  }

  /// Finds MAVLink magic byte in buffer.
  int _findMagicByte() {
    for (int i = 0; i < _buffer.length; i++) {
      if (_buffer[i] == MavlinkConstants.v2Magic ||
          _buffer[i] == MavlinkConstants.v1Magic) {
        return i;
      }
    }
    return -1;
  }

  /// Parses MAVLink frame from byte array.
  MavlinkFrame? _parseFrame(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);

    final magic = bd.getUint8(0);
    final payloadLength = bd.getUint8(1);
    final incompatFlags = bd.getUint8(2);
    final compatFlags = bd.getUint8(3);
    final sequence = bd.getUint8(4);
    final systemId = bd.getUint8(5);
    final componentId = bd.getUint8(6);

    // 24-bit message ID (Little Endian)
    final messageId = bd.getUint8(7) |
        (bd.getUint8(8) << 8) |
        (bd.getUint8(9) << 16);

    // Payload
    final payloadStart = MavlinkConstants.v2HeaderSize;
    final payload = bytes.sublist(payloadStart, payloadStart + payloadLength);

    // Checksum (Little Endian)
    final checksumOffset = payloadStart + payloadLength;
    final checksum = bd.getUint16(checksumOffset, Endian.little);

    // Signature (optional)
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

    // CRC verification
    if (!validateCrc(frame)) {
      _crcErrors++;
      return null;
    }

    _validFrames++;
    return frame;
  }

  /// Validates CRC of MAVLink frame.
  bool validateCrc(MavlinkFrame frame) {
    final messageDef = spec.getMessage(frame.messageId);
    if (messageDef == null) {
      _unknownMessages++;
      // Unknown message cannot verify CRC, pass for now
      return true;
    }

    final calculatedCrc = calculateCrc(frame, messageDef.crcExtra);
    return calculatedCrc == frame.checksum;
  }

  /// Calculates CRC-16/MCRF4XX.
  int calculateCrc(MavlinkFrame frame, int crcExtra) {
    int crc = 0xFFFF;

    // Header (excluding magic, bytes 1-9)
    for (int i = 1; i < MavlinkConstants.v2HeaderSize; i++) {
      crc = _crcAccumulate(frame.rawBytes[i], crc);
    }

    // Payload
    for (final byte in frame.payload) {
      crc = _crcAccumulate(byte, crc);
    }

    // CRC Extra
    crc = _crcAccumulate(crcExtra, crc);

    return crc;
  }

  /// CRC-16/MCRF4XX accumulate calculation
  int _crcAccumulate(int byte, int crc) {
    final tmp = byte ^ (crc & 0xFF);
    final tmp2 = tmp ^ ((tmp << 4) & 0xFF);
    return ((crc >> 8) ^ (tmp2 << 8) ^ (tmp2 << 3) ^ (tmp2 >> 4)) & 0xFFFF;
  }

  /// Parses payload and returns field value map.
  ///
  /// Keys are TAGs in "{MessageName}.{FieldName}" format.
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
        // Default value on field read failure
        result[tag] = null;
      }
    }

    return result;
  }

  /// Reads field value.
  dynamic _readFieldValue(ByteData bd, MavlinkFieldDef field) {
    if (field.offset >= bd.lengthInBytes) {
      return null;
    }

    if (field.isArray) {
      return _readArrayField(bd, field);
    }

    return _readScalarField(bd, field);
  }

  /// Reads scalar field value.
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

  /// Reads array field value.
  dynamic _readArrayField(ByteData bd, MavlinkFieldDef field) {
    final baseType = field.baseType;

    // char array converts to string
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

    // Numeric array
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

  /// Reads value at specified offset.
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

  /// Returns type size.
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

  /// Clears buffer.
  void clearBuffer() {
    _buffer.clear();
  }
}
