import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'communication_interface.dart';

/// MAVLink v2 헤더 바이트
const int mavlinkV2Magic = 0xFD;

/// MAVLink v1 헤더 바이트 (호환용)
const int mavlinkV1Magic = 0xFE;

// ─── Isolate 메시지 타입 ─────────────────────────────────────────────────

/// 메인 isolate → worker isolate 명령
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

/// worker isolate → 메인 isolate 응답
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

// ─── Worker Isolate 진입점 ───────────────────────────────────────────────

/// Isolate 진입점 — 포트 열기, 수신 루프.
///
/// MAVLink 프레임 동기화는 메인 isolate의 MavlinkParser에서 처리하므로
/// 여기서는 원시 바이트 데이터만 전달합니다.
void _serialIsolateEntry(SendPort mainSendPort) {
  final cmdReceivePort = ReceivePort();
  // worker의 수신 포트를 메인에 전달
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
          replyPort?.send(_RespError('포트 열기 실패: ${err?.message ?? "unknown"}'));
          return;
        }

        port!.config = config;
        replyPort?.send(_RespConnected());

        reader = SerialPortReader(port!);
        subscription = reader!.stream.listen(
          (data) {
            // 원시 바이트 데이터를 메인 isolate로 전달
            replyPort?.send(_RespData(Uint8List.fromList(data)));
          },
          onError: (e) {
            replyPort?.send(_RespError('수신 오류: $e'));
            _cleanup(port, reader, subscription, replyPort);
          },
          onDone: () {
            _cleanup(port, reader, subscription, replyPort);
          },
        );
      } catch (e) {
        replyPort?.send(_RespError('포트 오류: $e'));
      }
    } else if (msg is _CmdSend) {
      // 데이터 전송
      if (port != null && port!.isOpen) {
        try {
          port!.write(msg.data);
        } catch (e) {
          replyPort?.send(_RespError('전송 오류: $e'));
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

// ─── SerialCommunication (CommunicationInterface 구현) ─────────────────────

/// 시리얼 통신 구현체
///
/// [CommunicationInterface]를 구현하여 시리얼 포트를 통한 통신을 제공합니다.
/// MAVLink v2 프레임 동기화(0xFD 헤더)는 [MavlinkParser]에서 처리합니다.
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

  /// 현재 시스템에서 사용 가능한 시리얼 포트 이름 목록을 반환합니다.
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

      // Isolate 정리를 위한 짧은 지연
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _cleanup();
  }

  @override
  Future<void> send(Uint8List data) async {
    if (!isConnected || _workerSendPort == null) {
      throw StateError('연결되지 않은 상태에서는 데이터를 전송할 수 없습니다.');
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
