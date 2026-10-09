# MAVLink 메시지 송수신 기능 설계 문서

## 개요

이 문서는 MAV-Flow Flutter Windows Desktop 앱에 MAVLink 프로토콜 기반 메시지 송수신 기능을 추가하기 위한 기술 설계를 정의합니다. 기존 시리얼 모니터링 아키텍처를 확장하여 MAVLink v2 표준을 지원하며, 역할 기반 메시지 관리 시스템을 구현합니다.

---

## 아키텍처 개요

### 시스템 구조

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              UI Layer                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  ReceivePanel   │  │   SendPanel     │  │    SettingsPanel        │  │
│  │  (수신 화면)     │  │   (송신 화면)    │  │    (설정 화면)          │  │
│  │                 │  │                 │  │  [메시지 규격 변환]      │  │
│  └────────┬────────┘  └────────┬────────┘  └────────────┬────────────┘  │
└───────────┼─────────────────────┼───────────────────────┼───────────────┘
            │                     │                       │
            ▼                     ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           State Layer                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      MavlinkState (ChangeNotifier)               │    │
│  │  - currentRole: DeviceRole                                       │    │
│  │  - dataTable: Map<String, DataTableEntry>                        │    │
│  │  - rxMessageFilter / txMessageList                               │    │
│  │  - autoSendConfig: Map<String, AutoSendConfig>                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
            │                     │                       │
            ▼                     ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Service Layer                                    │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────┐    │
│  │ MavlinkParser │  │ MavlinkCodec  │  │   MavlinkSpecLoader       │    │
│  │ (메시지 파싱)  │  │ (메시지 생성)  │  │   (XML→JSON 변환)         │    │
│  └───────────────┘  └───────────────┘  └───────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              CommunicationInterface (추상 인터페이스)             │    │
│  │  └── SerialCommunication (시리얼 구현)                           │    │
│  │      └── (향후: TcpCommunication, UdpCommunication)              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Data Layer                                       │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────┐    │
│  │ common.xml    │  │ messages.json │  │   role_config.json        │    │
│  │ (MAVLink 규격)│  │ (런타임 규격)  │  │   (역할별 메시지 설정)     │    │
│  └───────────────┘  └───────────────┘  └───────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 레이어 책임

| 레이어 | 책임 |
|--------|------|
| **UI Layer** | 사용자 인터페이스 렌더링, 입력 처리 |
| **State Layer** | 앱 전역 상태 관리, UI 갱신 트리거 |
| **Service Layer** | 비즈니스 로직, 프로토콜 처리, 통신 추상화 |
| **Data Layer** | MAVLink 규격 파일, 설정 파일 저장 |

---

## 컴포넌트 설계

### 1. 통신 인터페이스 (CommunicationInterface)

향후 TCP/UDP 확장을 위한 추상화 계층을 제공합니다.

```dart
/// 통신 인터페이스 추상 클래스
/// 시리얼, TCP, UDP 등 다양한 통신 방식을 추상화합니다.
abstract class CommunicationInterface {
  /// 연결 상태 스트림
  Stream<ConnectionState> get connectionState;
  
  /// 수신된 바이트 스트림
  Stream<Uint8List> get dataStream;
  
  /// 연결을 시작합니다.
  Future<void> connect(Map<String, dynamic> config);
  
  /// 연결을 종료합니다.
  Future<void> disconnect();
  
  /// 데이터를 전송합니다.
  Future<void> send(Uint8List data);
  
  /// 연결 여부를 반환합니다.
  bool get isConnected;
  
  /// 리소스를 해제합니다.
  void dispose();
}

/// 연결 상태 열거형
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
```

### 2. 시리얼 통신 구현 (SerialCommunication)

기존 `SerialService`를 확장하여 MAVLink v2 프레임 동기화(0xFD 헤더)를 지원합니다.

```dart
/// 시리얼 통신 구현체
/// MAVLink v2 프레임 동기화(0xFD 헤더)를 지원합니다.
class SerialCommunication implements CommunicationInterface {
  static const int mavlinkV2Header = 0xFD;
  
  Isolate? _isolate;
  SendPort? _workerSendPort;
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _dataController = StreamController<Uint8List>.broadcast();
  
  @override
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  @override
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  @override
  Future<void> connect(Map<String, dynamic> config) async {
    // Isolate 기반 비동기 시리얼 통신 시작
    // MAVLink v2 프레임 동기화 로직 포함
  }
  
  @override
  Future<void> send(Uint8List data) async {
    // MAVLink 메시지 전송
  }
  
  // ... 기타 구현
}
```

### 3. MAVLink 메시지 규격 로더 (MavlinkSpecLoader)

MAVLink 표준 XML 파일을 파싱하여 JSON으로 변환합니다.

```dart
/// MAVLink XML 규격 파일을 파싱하여 JSON으로 변환하는 로더
class MavlinkSpecLoader {
  /// XML 파일들을 파싱하여 통합된 메시지 규격 JSON을 생성합니다.
  static Future<Map<String, dynamic>> loadFromXml(List<String> xmlPaths) async {
    // XML 파싱 및 JSON 변환
  }
  
  /// JSON 규격 파일을 로드합니다. (런타임 사용)
  static Future<Map<String, dynamic>> loadFromJson(String jsonPath) async {
    // JSON 로드
  }
  
  /// XML을 파싱하여 JSON 파일로 저장합니다.
  static Future<void> convertXmlToJson({
    required List<String> xmlPaths,
    required String outputJsonPath,
  }) async {
    // XML → JSON 변환 및 저장
  }
}

/// 파싱된 MAVLink 메시지 정의
class MavlinkMessageDef {
  final int id;
  final String name;
  final String description;
  final List<MavlinkFieldDef> fields;
  final int crcExtra;
  
  const MavlinkMessageDef({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    required this.crcExtra,
  });
}

/// 파싱된 MAVLink 필드 정의
class MavlinkFieldDef {
  final String name;
  final String type;
  final int arrayLength; // 배열이 아니면 0
  final String description;
  final String? units;
  final String? enumName;
  
  const MavlinkFieldDef({
    required this.name,
    required this.type,
    this.arrayLength = 0,
    required this.description,
    this.units,
    this.enumName,
  });
}
```

### 4. MAVLink 메시지 파서 (MavlinkParser)

수신된 바이트 스트림에서 MAVLink v2 메시지를 파싱합니다.

```dart
/// MAVLink v2 메시지 파서
/// 바이트 스트림에서 MAVLink 프레임을 추출하고 페이로드를 파싱합니다.
class MavlinkParser {
  final Map<String, dynamic> messageSpec;
  
  MavlinkParser(this.messageSpec);
  
  /// 바이트 스트림에서 완전한 MAVLink 프레임을 추출합니다.
  /// 불완전한 데이터는 버퍼에 유지됩니다.
  List<MavlinkFrame> extractFrames(Uint8List data);
  
  /// MAVLink 프레임의 CRC를 검증합니다.
  bool validateCrc(MavlinkFrame frame);
  
  /// 페이로드를 파싱하여 필드 값 맵을 반환합니다.
  /// 키는 "{MessageName}.{FieldName}" 형식의 TAG입니다.
  Map<String, FieldValue> parsePayload(MavlinkFrame frame);
}

/// MAVLink v2 프레임 구조
class MavlinkFrame {
  final int magic;          // 0xFD (MAVLink v2)
  final int payloadLength;
  final int incompatFlags;
  final int compatFlags;
  final int sequence;
  final int systemId;
  final int componentId;
  final int messageId;      // 24-bit message ID
  final Uint8List payload;
  final int checksum;
  final Uint8List? signature; // 서명 (옵션)
  
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
  });
}
```

### 5. MAVLink 메시지 코덱 (MavlinkCodec)

메시지 필드 값을 MAVLink v2 바이너리 형식으로 직렬화합니다.

```dart
/// MAVLink 메시지 직렬화/역직렬화 코덱
class MavlinkCodec {
  final Map<String, dynamic> messageSpec;
  
  MavlinkCodec(this.messageSpec);
  
  /// 필드 값 맵을 MAVLink v2 바이너리 메시지로 직렬화합니다.
  Uint8List encode({
    required int messageId,
    required int systemId,
    required int componentId,
    required int sequence,
    required Map<String, dynamic> fieldValues,
  });
  
  /// MAVLink 프레임의 페이로드를 필드 값 맵으로 역직렬화합니다.
  Map<String, dynamic> decode(MavlinkFrame frame);
  
  /// 메시지 ID에 해당하는 CRC Extra 값을 계산합니다.
  int getCrcExtra(int messageId);
  
  /// MAVLink CRC-16/MCRF4XX를 계산합니다.
  int calculateCrc(Uint8List data, int crcExtra);
}
```

### 6. Data Table 관리 (DataTableEntry)

수신값과 전송값을 분리하여 관리하는 데이터 모델입니다.

```dart
/// Data Table의 각 필드 항목
/// 현재값(수신된 값)과 전송값(사용자 수정 값)을 분리하여 관리합니다.
class DataTableEntry {
  final String tag;           // "{MessageName}.{FieldName}" 형식
  final String messageName;
  final String fieldName;
  final String dataType;
  final String? units;
  final String description;
  
  dynamic currentValue;       // 수신된 값 (읽기 전용)
  dynamic sendValue;          // 전송할 값 (사용자 수정 가능)
  DateTime? lastUpdated;      // 마지막 수신 시간
  
  DataTableEntry({
    required this.tag,
    required this.messageName,
    required this.fieldName,
    required this.dataType,
    this.units,
    required this.description,
    this.currentValue,
    this.sendValue,
  });
  
  /// TAG를 생성합니다.
  static String createTag(String messageName, String fieldName) {
    return '$messageName.$fieldName';
  }
}
```

### 7. 역할 설정 (RoleConfig)

각 역할별 송수신 메시지 목록을 관리합니다.

```dart
/// 장치 역할 열거형
enum DeviceRole {
  gen3,   // Communication Gateway 3세대 (데이터 수집, 프로토콜 변환, 메시지 전달)
  mc,     // Mission Computer
  fcc,    // Flight Control Computer
  gcs,    // Ground Control Station
}

/// 역할별 메시지 설정
class RoleConfig {
  final DeviceRole role;
  final int systemId;
  final int componentId;
  final List<int> txMessageIds;  // 송신 가능한 메시지 ID 목록
  final List<int> rxMessageIds;  // 수신할 메시지 ID 목록
  
  const RoleConfig({
    required this.role,
    required this.systemId,
    required this.componentId,
    required this.txMessageIds,
    required this.rxMessageIds,
  });
}

/// 역할 설정 로더
class RoleConfigLoader {
  /// JSON 설정 파일에서 역할 설정을 로드합니다.
  static Future<Map<DeviceRole, RoleConfig>> load(String configPath);
}
```

### 8. 자동 전송 설정 (AutoSendConfig)

메시지별 자동 전송 주기를 관리합니다.

```dart
/// 자동 전송 설정
class AutoSendConfig {
  final int messageId;
  final String messageName;
  bool enabled;
  int intervalMs;             // 전송 주기 (밀리초)
  Timer? _timer;
  
  AutoSendConfig({
    required this.messageId,
    required this.messageName,
    this.enabled = false,
    this.intervalMs = 500,
  });
  
  /// 자동 전송을 시작합니다.
  void start(void Function() onTick) {
    stop();
    if (enabled) {
      _timer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => onTick(),
      );
    }
  }
  
  /// 자동 전송을 중지합니다.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
```

### 9. 앱 상태 관리 (MavlinkState)

기존 `MonitorState`를 확장하여 MAVLink 기능을 통합합니다.

```dart
/// MAVLink 기능을 포함한 앱 전역 상태
class MavlinkState extends ChangeNotifier {
  // ─── 역할 관리 ───────────────────────────────────────────────
  DeviceRole _currentRole = DeviceRole.gcs;
  Map<DeviceRole, RoleConfig> _roleConfigs = {};
  
  DeviceRole get currentRole => _currentRole;
  RoleConfig get currentRoleConfig => _roleConfigs[_currentRole]!;
  
  void setRole(DeviceRole role) {
    _currentRole = role;
    _updateMessageFilters();
    notifyListeners();
  }
  
  // ─── 메시지 규격 ─────────────────────────────────────────────
  Map<String, dynamic>? messageSpec;
  Map<int, MavlinkMessageDef> _messageDefs = {};
  
  // ─── Data Table ─────────────────────────────────────────────
  final Map<String, DataTableEntry> dataTable = {};
  
  /// 수신 메시지로 Data Table을 업데이트합니다.
  void updateFromReceivedMessage(Map<String, FieldValue> fields) {
    for (final entry in fields.entries) {
      final tableEntry = dataTable[entry.key];
      if (tableEntry != null) {
        tableEntry.currentValue = entry.value.convertedValue;
        tableEntry.lastUpdated = DateTime.now();
      }
    }
    notifyListeners();
  }
  
  /// 전송값을 업데이트합니다.
  void updateSendValue(String tag, dynamic value) {
    final entry = dataTable[tag];
    if (entry != null) {
      entry.sendValue = value;
      notifyListeners();
    }
  }
  
  // ─── 자동 전송 ───────────────────────────────────────────────
  final Map<int, AutoSendConfig> autoSendConfigs = {};
  
  void toggleAutoSend(int messageId, bool enabled) {
    final config = autoSendConfigs[messageId];
    if (config != null) {
      config.enabled = enabled;
      if (enabled) {
        config.start(() => _sendMessage(messageId));
      } else {
        config.stop();
      }
      notifyListeners();
    }
  }
  
  void setAutoSendInterval(int messageId, int intervalMs) {
    final config = autoSendConfigs[messageId];
    if (config != null) {
      config.intervalMs = intervalMs;
      if (config.enabled) {
        config.start(() => _sendMessage(messageId));
      }
      notifyListeners();
    }
  }
  
  // ─── 통신 ───────────────────────────────────────────────────
  CommunicationInterface? _communication;
  MavlinkParser? _parser;
  MavlinkCodec? _codec;
  int _sequence = 0;
  
  Future<void> sendMessage(int messageId) async {
    await _sendMessage(messageId);
  }
  
  Future<void> _sendMessage(int messageId) async {
    if (_communication == null || !_communication!.isConnected) return;
    
    final messageDef = _messageDefs[messageId];
    if (messageDef == null) return;
    
    // Data Table에서 전송값 수집
    final fieldValues = <String, dynamic>{};
    for (final field in messageDef.fields) {
      final tag = DataTableEntry.createTag(messageDef.name, field.name);
      final entry = dataTable[tag];
      if (entry != null) {
        fieldValues[field.name] = entry.sendValue ?? entry.currentValue ?? 0;
      }
    }
    
    final data = _codec!.encode(
      messageId: messageId,
      systemId: currentRoleConfig.systemId,
      componentId: currentRoleConfig.componentId,
      sequence: _sequence++ & 0xFF,
      fieldValues: fieldValues,
    );
    
    await _communication!.send(data);
  }
  
  // ─── 규격 재로딩 ─────────────────────────────────────────────
  Future<void> convertMessageSpec() async {
    // XML 파일을 다시 파싱하여 JSON 갱신
    await MavlinkSpecLoader.convertXmlToJson(
      xmlPaths: ['assets/mavlink/common.xml'],
      outputJsonPath: 'assets/mavlink/messages.json',
    );
    await _loadMessageSpec();
    notifyListeners();
  }
}
```

---

## 데이터 흐름

### 메시지 수신 흐름

```
SerialPort (Isolate)
    │
    ▼ 바이트 스트림
SerialCommunication.dataStream
    │
    ▼ MAVLink 프레임
MavlinkParser.extractFrames()
    │
    ▼ CRC 검증
MavlinkParser.validateCrc()
    │
    ▼ 페이로드 파싱
MavlinkParser.parsePayload()
    │
    ▼ Map<String, FieldValue>
MavlinkState.updateFromReceivedMessage()
    │
    ▼ notifyListeners()
UI (ReceivePanel) 갱신
```

### 메시지 송신 흐름

```
UI (SendPanel)
    │
    ▼ 필드 값 입력/수정
MavlinkState.updateSendValue()
    │
    ▼ 전송 버튼 클릭
MavlinkState.sendMessage()
    │
    ▼ Data Table에서 필드 값 수집
MavlinkCodec.encode()
    │
    ▼ Uint8List (MAVLink 바이너리)
SerialCommunication.send()
    │
    ▼
SerialPort (Isolate)
```

---

## 인터페이스 설계

### MAVLink v2 프레임 구조

```
+--------+--------+--------+--------+--------+--------+--------+--------+--------+
| Magic  | Length | Incompat| Compat | Seq    | SysID  | CompID | MsgID          |
| 0xFD   | (1)    | Flags   | Flags  | (1)    | (1)    | (1)    | (3 bytes, LE)  |
+--------+--------+--------+--------+--------+--------+--------+--------+--------+
| Payload (0-255 bytes)                                                          |
+--------+--------+--------+--------+--------+--------+--------+--------+--------+
| Checksum (CRC-16/MCRF4XX, 2 bytes, LE)                                        |
+--------+--------+--------+--------+--------+--------+--------+--------+--------+
| Signature (optional, 13 bytes)                                                 |
+--------+--------+--------+--------+--------+--------+--------+--------+--------+
```

### 역할 설정 파일 형식 (role_config.json)

```json
{
  "roles": {
    "gen3": {
      "systemId": 1,
      "componentId": 1,
      "txMessages": ["HEARTBEAT", "SYS_STATUS", "POWER_STATUS"],
      "rxMessages": ["COMMAND_LONG", "PARAM_SET"]
    },
    "mc": {
      "systemId": 1,
      "componentId": 2,
      "txMessages": ["HEARTBEAT", "ATTITUDE", "GLOBAL_POSITION_INT"],
      "rxMessages": ["COMMAND_LONG", "MISSION_ITEM"]
    },
    "fcc": {
      "systemId": 1,
      "componentId": 3,
      "txMessages": ["HEARTBEAT", "ATTITUDE", "VFR_HUD"],
      "rxMessages": ["COMMAND_LONG", "SET_MODE"]
    },
    "gcs": {
      "systemId": 255,
      "componentId": 0,
      "txMessages": ["COMMAND_LONG", "PARAM_REQUEST_READ", "MISSION_REQUEST"],
      "rxMessages": ["HEARTBEAT", "SYS_STATUS", "ATTITUDE", "GLOBAL_POSITION_INT"]
    }
  }
}
```

---

## 화면 레이아웃 설계

### 메인 화면 구조

```
┌─────────────────────────────────────────────────────────────────────────┐
│  [역할 선택: ▼ GCS]    [포트: COM3 ▼]  [115200 ▼]  [연결/해제]  [설정]  │
├────────────────────────────────┬────────────────────────────────────────┤
│                                │                                        │
│         수신 화면               │              송신 화면                 │
│    (ReceivePanel)              │         (SendPanel)                   │
│                                │                                        │
│  ┌──────────────────────────┐  │  ┌──────────────────────────────────┐  │
│  │ 필터: [메시지 선택 ▼]     │  │  │ 메시지: [HEARTBEAT ▼]            │  │
│  ├──────────────────────────┤  │  ├──────────────────────────────────┤  │
│  │ TAG              │ 현재값 │  │  │ 필드명          │ 전송값 │ 단위  │  │
│  │ HEARTBEAT.type   │ 6     │  │  │ type            │ [6   ] │       │  │
│  │ HEARTBEAT.auto.. │ 3     │  │  │ autopilot       │ [3   ] │       │  │
│  │ SYS_STATUS.on..  │ 0x1F  │  │  │ base_mode       │ [89  ] │       │  │
│  │ ...              │ ...   │  │  │ ...             │ ...    │ ...   │  │
│  └──────────────────────────┘  │  ├──────────────────────────────────┤  │
│                                │  │ [수동 전송]                       │  │
│                                │  ├──────────────────────────────────┤  │
│                                │  │ 자동 전송:                        │  │
│                                │  │ ☑ HEARTBEAT   500ms  [주기 변경] │  │
│                                │  │ ☐ SYS_STATUS  1000ms [주기 변경] │  │
│                                │  └──────────────────────────────────┘  │
├────────────────────────────────┴────────────────────────────────────────┤
│  수신: 1234 패킷  |  CRC 오류: 2  |  수신율: 10.0 Hz  |  연결됨         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 파일 구조

```
lib/
├── main.dart
├── models/
│   ├── field_value.dart          (기존, 확장)
│   ├── monitor_state.dart        (기존, MavlinkState로 대체)
│   ├── mavlink_state.dart        (신규)
│   ├── data_table_entry.dart     (신규)
│   ├── mavlink_frame.dart        (신규)
│   ├── mavlink_message_def.dart  (신규)
│   ├── role_config.dart          (신규)
│   └── auto_send_config.dart     (신규)
├── services/
│   ├── communication/
│   │   ├── communication_interface.dart  (신규)
│   │   └── serial_communication.dart     (신규, 기존 serial_service 대체)
│   ├── mavlink_parser.dart       (신규)
│   ├── mavlink_codec.dart        (신규)
│   ├── mavlink_spec_loader.dart  (신규)
│   ├── role_config_loader.dart   (신규)
│   ├── packet_parser.dart        (기존, 삭제 예정)
│   ├── serial_service.dart       (기존, 삭제 예정)
│   └── spec_loader.dart          (기존, 삭제 예정)
├── screens/
│   ├── main_screen.dart          (기존, 수정)
│   └── settings_screen.dart      (신규)
└── widgets/
    ├── role_selector.dart        (신규)
    ├── receive_panel.dart        (신규)
    ├── send_panel.dart           (신규)
    ├── message_selector.dart     (신규)
    ├── field_editor.dart         (신규)
    ├── auto_send_list.dart       (신규)
    ├── data_table_panel.dart     (기존, 수정)
    ├── serial_config_panel.dart  (기존, 수정)
    ├── filter_panel.dart         (기존)
    └── status_bar.dart           (기존, 수정)

assets/
├── mavlink/
│   ├── common.xml                (MAVLink 표준 XML)
│   └── messages.json             (런타임 사용 JSON, 자동 생성)
└── config/
    └── role_config.json          (역할별 메시지 설정)
```

---

## 에러 처리

### 통신 에러

| 에러 유형 | 처리 방법 |
|-----------|-----------|
| 포트 열기 실패 | SnackBar로 에러 메시지 표시, 연결 상태 초기화 |
| 연결 끊김 | 자동 전송 중지, 연결 상태 업데이트, UI 알림 |
| 전송 실패 | SnackBar로 에러 메시지 표시, 재시도 옵션 제공 |

### 파싱 에러

| 에러 유형 | 처리 방법 |
|-----------|-----------|
| CRC 오류 | 에러 카운트 증가, 해당 프레임 폐기, 로그 기록 |
| 알 수 없는 메시지 ID | 경고 로그, 프레임 폐기 (향후 확장 대비 저장 옵션) |
| 페이로드 크기 불일치 | 에러 로그, 프레임 폐기 |

### 규격 로딩 에러

| 에러 유형 | 처리 방법 |
|-----------|-----------|
| XML 파싱 실패 | 에러 다이얼로그 표시, 이전 규격 유지 |
| JSON 로드 실패 | 앱 시작 시 XML 재파싱 시도 |
| 역할 설정 로드 실패 | 기본 역할 설정 사용, 경고 표시 |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: TAG 형식 일관성

*For any* MAVLink 메시지의 모든 필드에 대해, 생성된 TAG는 항상 `{MessageName}.{FieldName}` 패턴을 따라야 하며, 메시지 이름과 필드 이름 사이에 정확히 하나의 마침표(`.`)가 포함되어야 합니다.

**Validates: Requirements FR-1.3, FR-7.3**

### Property 2: MAVLink 메시지 직렬화/역직렬화 라운드트립

*For any* 유효한 MAVLink 메시지 필드 값 집합에 대해, `MavlinkCodec.encode()`로 직렬화한 후 `MavlinkCodec.decode()`로 역직렬화하면 원본 필드 값과 동일한 값이 복원되어야 합니다.

**Validates: Requirements FR-1.2, FR-2.4**

### Property 3: 역할별 메시지 필터링

*For any* 선택된 역할(DeviceRole)에 대해, 송신 화면에 표시되는 메시지 목록은 해당 역할의 `txMessageIds`에 정의된 메시지만 포함해야 하며, 정의되지 않은 메시지는 표시되지 않아야 합니다.

**Validates: Requirements FR-3.2, FR-3.3**

### Property 4: Data Table 값 동기화

*For any* 메시지 선택 시, 송신 화면에 표시되는 필드 목록은 Data Table에 저장된 해당 메시지의 모든 필드를 포함해야 하며, 필드 값은 Data Table의 `sendValue`와 일치해야 합니다.

**Validates: Requirements FR-2.2, FR-2.3, FR-7.1**

### Property 5: 현재값/전송값 독립성

*For any* Data Table 필드에 대해, `sendValue`를 수정해도 `currentValue`는 변경되지 않아야 하며, 새로운 메시지 수신으로 `currentValue`가 업데이트되어도 `sendValue`는 변경되지 않아야 합니다.

**Validates: Requirements FR-7.2**

### Property 6: MAVLink v2 프레임 동기화

*For any* 바이트 스트림에서 0xFD(MAVLink v2 헤더)로 시작하고 유효한 길이 필드를 가진 연속된 바이트 시퀀스는 완전한 MAVLink 프레임으로 추출되어야 하며, 불완전한 프레임 데이터는 버퍼에 유지되어 다음 수신 데이터와 결합되어야 합니다.

**Validates: Requirements FR-4.2**

### Property 7: MAVLink XML to JSON 변환 보존

*For any* 유효한 MAVLink XML 메시지 정의에 대해, XML을 JSON으로 변환한 후 JSON에서 로드한 메시지 정의는 원본 XML에 정의된 모든 메시지 ID, 필드 이름, 필드 타입, 필드 설명을 정확히 포함해야 합니다.

**Validates: Requirements FR-5.3, NFR-2.2**

---

## 마이그레이션 계획

### Phase 1: 인프라 구축
1. `CommunicationInterface` 추상 클래스 정의
2. `SerialCommunication` 구현 (기존 `SerialService` 기반)
3. `MavlinkSpecLoader` 구현 (XML → JSON 변환)

### Phase 2: MAVLink 프로토콜 구현
1. `MavlinkParser` 구현 (프레임 동기화, CRC 검증, 페이로드 파싱)
2. `MavlinkCodec` 구현 (메시지 직렬화)
3. `DataTableEntry` 모델 구현

### Phase 3: 상태 관리 통합
1. `MavlinkState` 구현 (기존 `MonitorState` 확장)
2. `RoleConfig` 및 `RoleConfigLoader` 구현
3. `AutoSendConfig` 구현

### Phase 4: UI 구현
1. 역할 선택 위젯 (`RoleSelector`)
2. 수신 화면 (`ReceivePanel`)
3. 송신 화면 (`SendPanel`) 및 자동 전송 UI
4. 설정 화면 (`SettingsScreen`)

### Phase 5: 정리 및 테스트
1. 기존 YAML 기반 코드 제거
2. 단위 테스트 및 통합 테스트
3. 문서화

---

## 참고 자료

- [MAVLink Developer Guide](https://mavlink.io/en/)
- [MAVLink v2 Protocol](https://mavlink.io/en/guide/mavlink_version.html)
- [MAVLink Message Definitions (common.xml)](https://mavlink.io/en/messages/common.html)
- [CRC-16/MCRF4XX Algorithm](https://mavlink.io/en/guide/serialization.html#crc_extra)
