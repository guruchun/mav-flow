import 'dart:async';
import 'dart:typed_data';

/// 연결 상태 열거형
///
/// Flutter의 ConnectionState와 이름 충돌을 피하기 위해 SerialConnectionState로 명명
enum SerialConnectionState {
  /// 연결되지 않은 상태
  disconnected,

  /// 연결 시도 중
  connecting,

  /// 연결됨
  connected,

  /// 연결 오류 발생
  error,
}

/// 통신 인터페이스 추상 클래스
///
/// 시리얼, TCP, UDP 등 다양한 통신 방식을 추상화합니다.
/// 향후 TCP/UDP 확장을 위한 공통 인터페이스를 제공합니다.
abstract class CommunicationInterface {
  /// 연결 상태 스트림
  ///
  /// 연결 상태가 변경될 때마다 새로운 [SerialConnectionState]를 방출합니다.
  Stream<SerialConnectionState> get connectionState;

  /// 수신된 바이트 스트림
  ///
  /// 통신 채널을 통해 수신된 원시 바이트 데이터를 방출합니다.
  Stream<Uint8List> get dataStream;

  /// 현재 연결 상태
  SerialConnectionState get currentState;

  /// 연결 여부를 반환합니다.
  bool get isConnected;

  /// 연결을 시작합니다.
  ///
  /// [config]는 통신 방식에 따라 다른 설정을 포함합니다.
  /// - 시리얼: portName, baudRate, dataBits, parity, stopBits
  /// - TCP: host, port
  /// - UDP: localPort, remoteHost, remotePort
  ///
  /// 연결에 실패하면 예외를 던집니다.
  Future<void> connect(Map<String, dynamic> config);

  /// 연결을 종료합니다.
  ///
  /// 이미 연결이 종료된 상태에서 호출해도 안전합니다.
  Future<void> disconnect();

  /// 데이터를 전송합니다.
  ///
  /// [data]는 전송할 바이트 배열입니다.
  /// 연결되지 않은 상태에서 호출하면 예외를 던집니다.
  Future<void> send(Uint8List data);

  /// 리소스를 해제합니다.
  ///
  /// 연결을 종료하고 모든 스트림을 닫습니다.
  /// dispose() 호출 후에는 이 인스턴스를 다시 사용할 수 없습니다.
  void dispose();
}

/// 통신 설정 기본 클래스
abstract class CommunicationConfig {
  const CommunicationConfig();
  
  /// 설정을 Map으로 변환합니다.
  Map<String, dynamic> toMap();
}

/// 시리얼 통신 설정
class SerialConfig extends CommunicationConfig {
  /// 포트 이름 (예: "COM3", "/dev/ttyUSB0")
  final String portName;

  /// 보드레이트 (예: 9600, 115200, 57600)
  final int baudRate;

  /// 데이터 비트 수 (기본값: 8)
  final int dataBits;

  /// 패리티 (0: none, 1: odd, 2: even)
  final int parity;

  /// 스톱 비트 수 (1 또는 2)
  final int stopBits;

  const SerialConfig({
    required this.portName,
    required this.baudRate,
    this.dataBits = 8,
    this.parity = 0,
    this.stopBits = 1,
  });

  @override
  Map<String, dynamic> toMap() => {
        'portName': portName,
        'baudRate': baudRate,
        'dataBits': dataBits,
        'parity': parity,
        'stopBits': stopBits,
      };
}

/// TCP 통신 설정 (향후 확장용)
class TcpConfig extends CommunicationConfig {
  /// 호스트 주소
  final String host;

  /// 포트 번호
  final int port;

  const TcpConfig({
    required this.host,
    required this.port,
  });

  @override
  Map<String, dynamic> toMap() => {
        'host': host,
        'port': port,
      };
}

/// UDP 통신 설정 (향후 확장용)
class UdpConfig extends CommunicationConfig {
  /// 로컬 바인딩 포트
  final int localPort;

  /// 원격 호스트 주소
  final String remoteHost;

  /// 원격 포트 번호
  final int remotePort;

  const UdpConfig({
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
  });

  @override
  Map<String, dynamic> toMap() => {
        'localPort': localPort,
        'remoteHost': remoteHost,
        'remotePort': remotePort,
      };
}
