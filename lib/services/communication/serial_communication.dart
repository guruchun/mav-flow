import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'communication_interface.dart';

/// MAVLink v2 header byte
const int mavlinkV2Magic = 0xFD;

/// MAVLink v1 header byte (for compatibility)
const int mavlinkV1Magic = 0xFE;

// --- Isolate message types ---

/// Main isolate → worker isolate commands
sealed class _WorkerCommand {}

class _CmdConnect extends _WorkerCommand {
  final SendPort replyPort;
  final String portName;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final int parity;

  _CmdConnect({
    required this.replyPort,
    required this.portName,
    required this.baudRate,
    required this.dataBits,
    required this.stopBits,
    required this.parity,
  });
}

class _CmdDisconnect extends _WorkerCommand {}

class _CmdSend extends _WorkerCommand {
  final Uint8List data;
  _CmdSend(this.data);
}

/// Worker isolate → main isolate responses
sealed class _WorkerResponse {}

class _RespConnected extends _WorkerResponse {}

class _RespDisconnected extends _WorkerResponse {}

class _RespError extends _WorkerResponse {
  final String message;
  _RespError(this.message);
}

class _RespData extends _WorkerResponse {
  final Uint8List data;
  _RespData(this.data);
}

// --- Worker Isolate entry point ---

/// Isolate entry point — opens port, receive loop.
///
/// MAVLink frame synchronization is handled by MavlinkParser in main isolate,
/// so only raw byte data is passed here.
void _serialIsolateEntry(SendPort mainSendPort) {
  final cmdReceivePort = ReceivePort();
  // Send worker's receive port to main
  mainSendPort.send(cmdReceivePort.sendPort);

  SerialPort? port;
  SerialPortReader? reader;
  StreamSubscription? subscription;
  SendPort? replyPort;

  cmdReceivePort.listen((msg) {
    if (msg is _CmdConnect) {
      replyPort = msg.replyPort;

      try {
        port = SerialPort(msg.portName);

        final config = SerialPortConfig();
        config.baudRate = msg.baudRate;
        config.bits = msg.dataBits;
        config.stopBits = msg.stopBits;
        config.parity = msg.parity;

        if (!port!.openReadWrite()) {
          final err = SerialPort.lastError;
          replyPort?.send(_RespError('Failed to open port: ${err?.message ?? "unknown"}'));
          return;
        }

        port!.config = config;
        replyPort?.send(_RespConnected());

        reader = SerialPortReader(port!);
        subscription = reader!.stream.listen(
          (data) {
            // Pass raw byte data to main isolate
            replyPort?.send(_RespData(Uint8List.fromList(data)));
          },
          onError: (e) {
            replyPort?.send(_RespError('Receive error: $e'));
            _cleanup(port, reader, subscription, replyPort);
          },
          onDone: () {
            _cleanup(port, reader, subscription, replyPort);
          },
        );
      } catch (e) {
        replyPort?.send(_RespError('Port error: $e'));
      }
    } else if (msg is _CmdSend) {
      // Send data
      if (port != null && port!.isOpen) {
        try {
          port!.write(msg.data);
        } catch (e) {
          replyPort?.send(_RespError('Send error: $e'));
        }
      }
    } else if (msg is _CmdDisconnect) {
      _cleanup(port, reader, subscription, replyPort);
      port = null;
      reader = null;
      subscription = null;
    }
  });
}

void _cleanup(
  SerialPort? port,
  SerialPortReader? reader,
  StreamSubscription? subscription,
  SendPort? replyPort,
) {
  subscription?.cancel();
  reader?.close();
  if (port != null && port.isOpen) {
    port.close();
  }
  replyPort?.send(_RespDisconnected());
}

// --- SerialCommunication (CommunicationInterface implementation) ---

/// Serial communication implementation
///
/// Implements [CommunicationInterface] to provide serial port communication.
/// MAVLink v2 frame synchronization (0xFD header) is handled by [MavlinkParser].
class SerialCommunication implements CommunicationInterface {
  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _receivePort;

  final _connectionStateController =
      StreamController<SerialConnectionState>.broadcast();
  final _dataController = StreamController<Uint8List>.broadcast();

  SerialConnectionState _currentState = SerialConnectionState.disconnected;

  @override
  Stream<SerialConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<Uint8List> get dataStream => _dataController.stream;

  @override
  SerialConnectionState get currentState => _currentState;

  @override
  bool get isConnected => _currentState == SerialConnectionState.connected;

  /// Returns list of available serial port names on the current system.
  static List<String> availablePorts() => SerialPort.availablePorts;

  @override
  Future<void> connect(Map<String, dynamic> config) async {
    if (_isolate != null) {
      throw StateError('Already connected. Call disconnect() first.');
    }

    _updateState(SerialConnectionState.connecting);

    final portName = config['portName'] as String;
    final baudRate = config['baudRate'] as int;
    final dataBits = config['dataBits'] as int? ?? 8;
    final parity = config['parity'] as int? ?? SerialPortParity.none;
    final stopBits = config['stopBits'] as int? ?? 1;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_serialIsolateEntry, _receivePort!.sendPort);

    // Use a completer to get the worker SendPort
    final completer = Completer<SendPort>();
    
    // Single listener for all messages from worker
    _receivePort!.listen((msg) {
      if (msg is SendPort) {
        // First message: worker SendPort
        _workerSendPort = msg;
        completer.complete(msg);
      } else if (msg is _RespConnected) {
        _updateState(SerialConnectionState.connected);
      } else if (msg is _RespDisconnected) {
        _updateState(SerialConnectionState.disconnected);
      } else if (msg is _RespError) {
        _updateState(SerialConnectionState.error);
      } else if (msg is _RespData) {
        _dataController.add(msg.data);
      }
    });

    // Wait for worker SendPort
    await completer.future;

    // Send connect command
    _workerSendPort!.send(_CmdConnect(
      replyPort: _receivePort!.sendPort,
      portName: portName,
      baudRate: baudRate,
      dataBits: dataBits,
      stopBits: stopBits,
      parity: parity,
    ));
  }

  @override
  Future<void> disconnect() async {
    if (_workerSendPort != null) {
      _workerSendPort!.send(_CmdDisconnect());

      // Short delay for isolate cleanup
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _cleanup();
  }

  @override
  Future<void> send(Uint8List data) async {
    if (!isConnected || _workerSendPort == null) {
      throw StateError('Cannot send data when not connected.');
    }

    _workerSendPort!.send(_CmdSend(data));
  }

  @override
  void dispose() {
    _cleanup();
    _connectionStateController.close();
    _dataController.close();
  }

  void _cleanup() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerSendPort = null;
    _receivePort?.close();
    _receivePort = null;

    if (_currentState != SerialConnectionState.disconnected) {
      _updateState(SerialConnectionState.disconnected);
    }
  }

  void _updateState(SerialConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
    }
  }
}
