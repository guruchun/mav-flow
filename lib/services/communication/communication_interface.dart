import 'dart:async';
import 'dart:typed_data';

/// Connection state enumeration
///
/// Named SerialConnectionState to avoid name collision with Flutter's ConnectionState
enum SerialConnectionState {
  /// Not connected
  disconnected,

  /// Attempting to connect
  connecting,

  /// Connected
  connected,

  /// Connection error occurred
  error,
}

/// Communication interface abstract class
///
/// Abstracts various communication methods like serial, TCP, UDP.
/// Provides a common interface for future TCP/UDP extensions.
abstract class CommunicationInterface {
  /// Connection state stream
  ///
  /// Emits a new [SerialConnectionState] whenever connection state changes.
  Stream<SerialConnectionState> get connectionState;

  /// Received byte stream
  ///
  /// Emits raw byte data received through the communication channel.
  Stream<Uint8List> get dataStream;

  /// Current connection state
  SerialConnectionState get currentState;

  /// Returns whether connected.
  bool get isConnected;

  /// Starts connection.
  ///
  /// [config] contains different settings depending on communication method.
  /// - Serial: portName, baudRate, dataBits, parity, stopBits
  /// - TCP: host, port
  /// - UDP: localPort, remoteHost, remotePort
  ///
  /// Throws exception on connection failure.
  Future<void> connect(Map<String, dynamic> config);

  /// Terminates connection.
  ///
  /// Safe to call even when already disconnected.
  Future<void> disconnect();

  /// Sends data.
  ///
  /// [data] is the byte array to send.
  /// Throws exception if called when not connected.
  Future<void> send(Uint8List data);

  /// Releases resources.
  ///
  /// Terminates connection and closes all streams.
  /// This instance cannot be reused after dispose() is called.
  void dispose();
}

/// Communication config base class
abstract class CommunicationConfig {
  const CommunicationConfig();
  
  /// Converts config to Map.
  Map<String, dynamic> toMap();
}

/// Serial communication configuration
class SerialConfig extends CommunicationConfig {
  /// Port name (e.g., "COM3", "/dev/ttyUSB0")
  final String portName;

  /// Baud rate (e.g., 9600, 115200, 57600)
  final int baudRate;

  /// Data bits (default: 8)
  final int dataBits;

  /// Parity (0: none, 1: odd, 2: even)
  final int parity;

  /// Stop bits (1 or 2)
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

/// TCP communication configuration (for future extension)
class TcpConfig extends CommunicationConfig {
  /// Host address
  final String host;

  /// Port number
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

/// UDP communication configuration (for future extension)
class UdpConfig extends CommunicationConfig {
  /// Local binding port
  final int localPort;

  /// Remote host address
  final String remoteHost;

  /// Remote port number
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
