import 'dart:typed_data';

import '../models/mavlink_frame.dart';
import '../models/mavlink_message_def.dart';

/// MAVLink message serialization/deserialization codec
///
/// Serializes message field values to MAVLink v2 binary format.
class MavlinkCodec {
  /// Message specification
  final MavlinkSpec spec;

  MavlinkCodec(this.spec);

  /// Serializes a field value map to MAVLink v2 binary message.
  ///
  /// [messageId] is the message ID.
  /// [systemId] is the sender system ID.
  /// [componentId] is the sender component ID.
  /// [sequence] is the sequence number (0-255).
  /// [fieldValues] is a map of field names to values.
  Uint8List encode({
    required int messageId,
    required int systemId,
    required int componentId,
    required int sequence,
    required Map<String, dynamic> fieldValues,
  }) {
    final messageDef = spec.getMessage(messageId);
    if (messageDef == null) {
      throw ArgumentError('Unknown message ID: $messageId');
    }

    // Create payload
    final payload = _encodePayload(messageDef, fieldValues);

    // Build frame
    final frameSize = MavlinkConstants.v2HeaderSize +
        payload.length +
        MavlinkConstants.checksumSize;
    final frame = Uint8List(frameSize);
    final bd = ByteData.sublistView(frame);

    // Header
    bd.setUint8(0, MavlinkConstants.v2Magic);
    bd.setUint8(1, payload.length);
    bd.setUint8(2, 0); // incompatFlags
    bd.setUint8(3, 0); // compatFlags
    bd.setUint8(4, sequence & 0xFF);
    bd.setUint8(5, systemId);
    bd.setUint8(6, componentId);

    // 24-bit message ID (Little Endian)
    bd.setUint8(7, messageId & 0xFF);
    bd.setUint8(8, (messageId >> 8) & 0xFF);
    bd.setUint8(9, (messageId >> 16) & 0xFF);

    // Copy payload
    frame.setRange(MavlinkConstants.v2HeaderSize,
        MavlinkConstants.v2HeaderSize + payload.length, payload);

    // Calculate and add CRC
    final crc = _calculateCrc(frame, payload.length, messageDef.crcExtra);
    final checksumOffset = MavlinkConstants.v2HeaderSize + payload.length;
    bd.setUint16(checksumOffset, crc, Endian.little);

    return frame;
  }

  /// Encodes by message name.
  Uint8List encodeByName({
    required String messageName,
    required int systemId,
    required int componentId,
    required int sequence,
    required Map<String, dynamic> fieldValues,
  }) {
    final messageDef = spec.getMessageByName(messageName);
    if (messageDef == null) {
      throw ArgumentError('Unknown message name: $messageName');
    }

    return encode(
      messageId: messageDef.id,
      systemId: systemId,
      componentId: componentId,
      sequence: sequence,
      fieldValues: fieldValues,
    );
  }

  /// Encodes payload.
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
        // Ignore field write failures (keep default value 0)
      }
    }

    // Remove trailing zeros (MAVLink truncation)
    int truncatedLength = payload.length;
    while (truncatedLength > 0 && payload[truncatedLength - 1] == 0) {
      truncatedLength--;
    }

    // Keep at least 1 byte
    if (truncatedLength == 0 && payload.isNotEmpty) {
      truncatedLength = 1;
    }

    return payload.sublist(0, truncatedLength);
  }

  /// Writes field value.
  void _writeFieldValue(ByteData bd, MavlinkFieldDef field, dynamic value) {
    if (field.isArray) {
      _writeArrayField(bd, field, value);
    } else {
      _writeScalarField(bd, field, value);
    }
  }

  /// Writes scalar field value.
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

  /// Writes array field value.
  void _writeArrayField(ByteData bd, MavlinkFieldDef field, dynamic value) {
    final baseType = field.baseType;

    // char array (string)
    if (baseType == 'char' && value is String) {
      final bytes = value.codeUnits;
      for (int i = 0; i < field.arrayLength && i < bytes.length; i++) {
        bd.setUint8(field.offset + i, bytes[i]);
      }
      return;
    }

    // Numeric array
    if (value is List) {
      final unitSize = _getTypeSize(baseType);
      for (int i = 0; i < field.arrayLength && i < value.length; i++) {
        final offset = field.offset + (i * unitSize);
        _writeValueAtOffset(bd, offset, baseType, value[i]);
      }
    }
  }

  /// Writes value at specified offset.
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

  /// Calculates CRC-16/MCRF4XX.
  int _calculateCrc(Uint8List frame, int payloadLength, int crcExtra) {
    int crc = 0xFFFF;

    // Header (excluding magic, bytes 1-9)
    for (int i = 1; i < MavlinkConstants.v2HeaderSize; i++) {
      crc = _crcAccumulate(frame[i], crc);
    }

    // Payload
    for (int i = 0; i < payloadLength; i++) {
      crc = _crcAccumulate(frame[MavlinkConstants.v2HeaderSize + i], crc);
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
}
