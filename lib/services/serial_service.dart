import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

// ─── 시리얼 이벤트 타입 ────────────────────────────────────────────────────

sealed class SerialEvent {}

class SerialConnected extends SerialEvent {}

class SerialDisconnected extends SerialEvent {}

class SerialError extends SerialEvent {
  final String message;
  SerialError(this.message);
}

class SerialPacket extends SerialEvent {
  final Uint8List data;
  SerialPacket(this.data);
}

// ─── Isolate 메시지 타입 ─────────────────────────────────────────────────

/// 메인 isolate → worker isolate 명령
sealed class _WorkerCommand {}

class _CmdStart extends _WorkerCommand {
  final SendPort replyPort;
  final String portName;
  final int baudrate;
  final int databits;
  final int stopbits; // 1, 2
  final String parity; // "None", "Even", "Odd"
  final String flowcontrol; // "None", "RTS/CTS", "XON/XOFF"
  final int headerByte;
  final int frameSize;

  _CmdStart({
    required this.replyPort,
    required this.portName,
    required this.baudrate,
    required this.databits,
    required this.stopbits,
    required this.parity,
    required this.flowcontrol,
    required this.headerByte,
    required this.frameSize,
  });
}

class _CmdStop extends _WorkerCommand {}

// ─── 프레임 동기화 상태 ────────────────────────────────────────────────────

enum _FrameState { idle, accumulating }

// ─── Worker Isolate 진입점 ───────────────────────────────────────────────

/// Isolate 진입점 — 포트 열기, 수신 루프, 프레임 동기화.
///
/// Python SerialWorker._run() 에 대응하나,
/// Flutter에서는 background Thread 대신 Isolate를 사용한다.
void _serialIsolateEntry(SendPort mainSendPort) {
  final cmdReceivePort = ReceivePort();
  // worker의 수신 포트를 메인에 전달
  mainSendPort.send(cmdReceivePort.sendPort);

  SerialPort? port;
  SerialPortReader? reader;
  StreamSubscription? sub;

  var state = _FrameState.idle;
  var buffer = <int>[];
  var headerByte = 0xFE;
  var frameSize = 483;

  cmdReceivePort.listen((msg) {
    if (msg is _CmdStart) {
      headerByte = msg.headerByte;
      frameSize = msg.frameSize;

      try {
        port = SerialPort(msg.portName);

        final config = SerialPortConfig();
        config.baudRate = msg.baudrate;
        config.bits = msg.databits;
        config.stopBits = msg.stopbits;
        config.parity = _mapParity(msg.parity);

        if (msg.flowcontrol == 'RTS/CTS') {
          config.rts = SerialPortRts.flowControl;
          config.cts = SerialPortCts.flowControl;
        } else if (msg.flowcontrol == 'XON/XOFF') {
          config.xonXoff = SerialPortXonXoff.inOut;
        }

        if (!port!.openReadWrite()) {
          final err = SerialPort.lastError;
          msg.replyPort
              .send(SerialError('포트 열기 실패: ${err?.message ?? "unknown"}'));
          return;
        }

        port!.config = config;
        msg.replyPort.send(SerialConnected());

        reader = SerialPortReader(port!);
        sub = reader!.stream.listen(
          (data) {
            // 프레임 동기화 상태 머신 (Python _run() 동일 로직)
            for (final byte in data) {
              if (state == _FrameState.idle) {
                if (byte == headerByte) {
                  buffer = [byte];
                  state = _FrameState.accumulating;
                }
              } else {
                buffer.add(byte);
                if (buffer.length >= frameSize) {
                  msg.replyPort.send(SerialPacket(Uint8List.fromList(buffer)));
                  buffer = [];
                  state = _FrameState.idle;
                }
              }
            }
          },
          onError: (e) {
            msg.replyPort.send(SerialError('수신 오류: $e'));
            _cleanup(port, reader, sub, msg.replyPort);
          },
          onDone: () {
            _cleanup(port, reader, sub, msg.replyPort);
          },
        );
      } catch (e) {
        msg.replyPort.send(SerialError('포트 오류: $e'));
      }
    } else if (msg is _CmdStop) {
      _cleanup(port, reader, sub, mainSendPort);
    }
  });
}

void _cleanup(
  SerialPort? port,
  SerialPortReader? reader,
  StreamSubscription? sub,
  SendPort replyPort,
) {
  sub?.cancel();
  reader?.close();
  if (port != null && port.isOpen) {
    port.close();
  }
  replyPort.send(SerialDisconnected());
}

int _mapParity(String parity) {
  switch (parity) {
    case 'Even':
      return SerialPortParity.even;
    case 'Odd':
      return SerialPortParity.odd;
    default:
      return SerialPortParity.none;
  }
}

// ─── SerialService (메인 isolate 측) ────────────────────────────────────

/// 시리얼 포트를 관리하고 패킷 이벤트를 Stream으로 제공한다.
///
/// Python SerialWorker에 대응한다.
class SerialService {
  final Map<String, dynamic> spec;

  Isolate? _isolate;
  SendPort? _workerSendPort;
  final _eventController = StreamController<SerialEvent>.broadcast();

  /// 포트로부터 수신된 이벤트 스트림 (연결/해제/에러/패킷)
  Stream<SerialEvent> get events => _eventController.stream;

  SerialService(this.spec);

  /// 현재 시스템에서 사용 가능한 시리얼 포트 이름 목록을 반환한다.
  static List<String> availablePorts() => SerialPort.availablePorts;

  /// 시리얼 포트를 열고 수신을 시작한다.
  Future<void> openPort({
    required String portName,
    required int baudrate,
    String parity = 'None',
    int databits = 8,
    int stopbits = 1,
    String flowcontrol = 'None',
  }) async {
    if (_isolate != null) return;

    final packet = spec['packet'] as Map<String, dynamic>;
    final payloadSize = packet['payload_size'] as int;
    final frameSize = payloadSize + 3;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_serialIsolateEntry, receivePort.sendPort);

    // 첫 메시지: worker SendPort
    final completer = Completer<SendPort>();
    late StreamSubscription workerPortSub;
    workerPortSub = receivePort.listen((msg) {
      if (msg is SendPort) {
        completer.complete(msg);
        workerPortSub.cancel();
      }
    });
    _workerSendPort = await completer.future;

    // 이후 메시지: SerialEvent 스트림으로 중계
    receivePort.listen((msg) {
      if (msg is SerialEvent) {
        _eventController.add(msg);
      }
    });

    _workerSendPort!.send(_CmdStart(
      replyPort: receivePort.sendPort,
      portName: portName,
      baudrate: baudrate,
      databits: databits,
      stopbits: stopbits,
      parity: parity,
      flowcontrol: flowcontrol,
      headerByte: packet['header'] as int,
      frameSize: frameSize,
    ));
  }

  /// 시리얼 포트를 닫는다.
  void closePort() {
    _workerSendPort?.send(_CmdStop());
    Future.delayed(const Duration(milliseconds: 300), () {
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _workerSendPort = null;
    });
  }

  void dispose() {
    closePort();
    _eventController.close();
  }
}
