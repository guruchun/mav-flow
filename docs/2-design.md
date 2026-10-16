# MAV-Flow Technical Design Document

## Overview

This document defines the technical design for the MAV-Flow Flutter Windows Desktop application. The architecture supports MAVLink v2 protocol message transmission and reception with a role-based message management system.

---

## Architecture Overview

### System Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              UI Layer                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  ReceivePanel   │  │   SendPanel     │  │    Settings Screen      │  │
│  │  (RX Data)      │  │   (TX Data)     │  │    (Theme, Convert,     │  │
│  │                 │  │                 │  │     Update Check)       │  │
│  └────────┬────────┘  └────────┬────────┘  └────────────┬────────────┘  │
└───────────┼─────────────────────┼───────────────────────┼───────────────┘
            │                     │                       │
            ▼                     ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           State Layer                                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      MavlinkState (ChangeNotifier)               │    │
│  │  - currentRole: RoleConfig                                       │    │
│  │  - dataTable: Map<String, DataTableEntry>                        │    │
│  │  - rxMessageFilter / txMessageList                               │    │
│  │  - autoSendConfigs: Map<String, AutoSendConfig>                  │    │
│  │  - connectionState, rxCount, txCount, crcErrors                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      AppSettings (ChangeNotifier)                │    │
│  │  - isDarkMode: bool                                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
            │                     │                       │
            ▼                     ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Service Layer                                    │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────┐    │
│  │ MavlinkParser │  │ MavlinkCodec  │  │   MavlinkSpecLoader       │    │
│  │ (Parse frames)│  │ (Encode msgs) │  │   (XML→JSON conversion)   │    │
│  └───────────────┘  └───────────────┘  └───────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              CommunicationInterface (Abstract)                   │    │
│  │  └── SerialCommunication (Serial port implementation)            │    │
│  │      └── (Future: TcpCommunication, UdpCommunication)            │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      UpdateService                               │    │
│  │  (GitHub Releases API, download, install)                        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Data Layer                                       │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────┐    │
│  │ common.xml    │  │ messages.json │  │   role_config.json        │    │
│  │ (MAVLink spec)│  │ (Runtime spec)│  │   (Role definitions)      │    │
│  └───────────────┘  └───────────────┘  └───────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Responsibility |
|-------|----------------|
| **UI Layer** | User interface rendering, input handling, widget composition |
| **State Layer** | Global app state management, UI update triggers via ChangeNotifier |
| **Service Layer** | Business logic, protocol processing, communication abstraction |
| **Data Layer** | MAVLink specification files, configuration files storage |

---

## Component Design

### 1. Communication Interface (CommunicationInterface)

Provides abstraction layer for future TCP/UDP extensions.

```dart
/// Abstract communication interface
/// Abstracts various communication methods: serial, TCP, UDP, etc.
abstract class CommunicationInterface {
  /// Connection state stream
  Stream<ConnectionState> get connectionState;
  
  /// Received byte stream
  Stream<Uint8List> get dataStream;
  
  /// Start connection
  Future<void> connect(Map<String, dynamic> config);
  
  /// Close connection
  Future<void> disconnect();
  
  /// Send data
  Future<void> send(Uint8List data);
  
  /// Connection status
  bool get isConnected;
  
  /// Release resources
  void dispose();
}

/// Connection state enumeration
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
```

### 2. Serial Communication (SerialCommunication)

Implements serial port communication with MAVLink v2 frame synchronization.

```dart
/// Serial communication implementation
/// Supports MAVLink v2 frame synchronization (0xFD header)
class SerialCommunication implements CommunicationInterface {
  static const int mavlinkV2Header = 0xFD;
  
  SerialPort? _port;
  SerialPortReader? _reader;
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _dataController = StreamController<Uint8List>.broadcast();
  
  @override
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  @override
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  @override
  Future<void> connect(Map<String, dynamic> config) async {
    final portName = config['portName'] as String;
    final baudRate = config['baudRate'] as int;
    // Open port and start reading
  }
  
  @override
  Future<void> send(Uint8List data) async {
    _port?.write(data);
  }
}
```

### 3. MAVLink Specification Loader (MavlinkSpecLoader)

Parses MAVLink standard XML files and converts to JSON.

```dart
/// Parses MAVLink XML specification files and converts to JSON
class MavlinkSpecLoader {
  /// Load and parse XML files to generate unified message spec JSON
  static Future<Map<String, MavlinkMessageDef>> loadFromXml(
    List<String> xmlPaths,
    Set<String> includedMessages,
  );
  
  /// Load JSON specification file (runtime use)
  static Future<Map<String, MavlinkMessageDef>> loadFromJson(String jsonPath);
  
  /// Convert XML to JSON and save
  static Future<void> convertXmlToJson({
    required String xmlFolderPath,
    required String outputJsonPath,
    required Set<String> includedMessages,
  });
}
```

### 4. MAVLink Message Definition Models

```dart
/// Parsed MAVLink message definition
class MavlinkMessageDef {
  final int id;
  final String name;
  final String description;
  final List<MavlinkFieldDef> fields;
  final int crcExtra;
}

/// Parsed MAVLink field definition
class MavlinkFieldDef {
  final String name;
  final String type;          // uint8_t, int16_t, float, etc.
  final int arrayLength;      // 0 if not array
  final String description;
  final String? units;        // m/s, deg, etc.
  final String? enumName;     // Reference to enum type
  final bool isBitmask;       // For bitmask display
}

/// Parsed MAVLink enum definition
class MavlinkEnumDef {
  final String name;
  final String description;
  final bool isBitmask;
  final List<MavlinkEnumEntry> entries;
}

/// Enum entry
class MavlinkEnumEntry {
  final int value;
  final String name;
  final String description;
}
```

### 5. MAVLink Parser (MavlinkParser)

Parses MAVLink v2 messages from received byte stream.

```dart
/// MAVLink v2 message parser
/// Extracts MAVLink frames from byte stream and parses payload
class MavlinkParser {
  final Map<String, MavlinkMessageDef> messageDefs;
  final List<int> _buffer = [];
  
  /// Extract complete MAVLink frames from byte stream
  /// Incomplete data is retained in buffer
  List<MavlinkFrame> parseBytes(Uint8List data);
  
  /// Validate MAVLink frame CRC
  bool validateCrc(MavlinkFrame frame);
  
  /// Parse payload to field value map
  /// Keys are TAGs in "{MessageName}.{FieldName}" format
  Map<String, dynamic> parsePayload(MavlinkFrame frame);
}

/// MAVLink v2 frame structure
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
}
```

### 6. MAVLink Codec (MavlinkCodec)

Serializes message field values to MAVLink v2 binary format.

```dart
/// MAVLink message serialization/deserialization codec
class MavlinkCodec {
  final Map<String, MavlinkMessageDef> messageDefs;
  
  /// Serialize field value map to MAVLink v2 binary message
  Uint8List encode({
    required String messageName,
    required int systemId,
    required int componentId,
    required int sequence,
    required Map<String, dynamic> fieldValues,
  });
  
  /// Calculate MAVLink CRC-16/MCRF4XX
  int calculateCrc(Uint8List data, int crcExtra);
  
  /// Get CRC extra for message
  int getCrcExtra(String messageName);
}
```

### 7. Data Table Entry (DataTableEntry)

Data model managing separate received and send values.

```dart
/// Data Table field entry
/// Manages current value (received) and send value (user-modified) separately
class DataTableEntry {
  final String tag;           // "{MessageName}.{FieldName}" format
  final String messageName;
  final String fieldName;
  final String dataType;
  final String? units;
  final String description;
  final String? enumName;
  final bool isBitmask;
  
  dynamic currentValue;       // Received value (read-only display)
  dynamic sendValue;          // Value to send (user-modifiable)
  DateTime? lastUpdated;      // Last receive time
  
  /// Create TAG
  static String createTag(String messageName, String fieldName) {
    return '$messageName.$fieldName';
  }
}
```

### 8. Role Configuration (RoleConfig)

Manages TX/RX message lists per role.

```dart
/// Role configuration
class RoleConfig {
  final String id;            // gcs, fcc, mc, gen3
  final String name;          // Display name
  final String description;
  final int systemId;
  final int componentId;
  final List<String> txMessages;  // TX message names
  final List<String> rxMessages;  // RX message names
}

/// Role configuration loader
class RoleConfigLoader {
  /// Load role configurations from JSON file
  static Future<Map<String, RoleConfig>> load(String configPath);
}
```

### 9. Auto Send Configuration (AutoSendConfig)

Manages auto-send interval per message.

```dart
/// Auto send configuration
class AutoSendConfig {
  final String messageName;
  bool enabled;
  int intervalMs;             // Send interval (milliseconds)
  Timer? _timer;
  
  /// Start auto send
  void start(void Function() onTick) {
    stop();
    if (enabled) {
      _timer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => onTick(),
      );
    }
  }
  
  /// Stop auto send
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
```

### 10. App State Management (MavlinkState)

Central state management for MAVLink functionality.

```dart
/// MAVLink app global state
class MavlinkState extends ChangeNotifier {
  // ─── Role Management ────────────────────────────────────────
  RoleConfig? _currentRole;
  Map<String, RoleConfig> _roleConfigs = {};
  
  RoleConfig? get currentRole => _currentRole;
  
  void setRole(String roleId) {
    _currentRole = _roleConfigs[roleId];
    _initializeDataTable();
    notifyListeners();
  }
  
  // ─── Message Specifications ─────────────────────────────────
  Map<String, MavlinkMessageDef> messageDefs = {};
  Map<String, MavlinkEnumDef> enumDefs = {};
  
  // ─── Data Table ─────────────────────────────────────────────
  final Map<String, DataTableEntry> dataTable = {};
  
  /// Update Data Table from received message
  void updateFromReceivedMessage(String messageName, Map<String, dynamic> fields);
  
  /// Update send value
  void updateSendValue(String tag, dynamic value);
  
  // ─── Auto Send ──────────────────────────────────────────────
  final Map<String, AutoSendConfig> autoSendConfigs = {};
  
  void toggleAutoSend(String messageName, bool enabled);
  void setAutoSendInterval(String messageName, int intervalMs);
  
  // ─── Communication ──────────────────────────────────────────
  CommunicationInterface? _communication;
  MavlinkParser? _parser;
  MavlinkCodec? _codec;
  int _sequence = 0;
  
  // ─── Statistics ─────────────────────────────────────────────
  int rxCount = 0;
  int txCount = 0;
  int crcErrors = 0;
  
  Future<void> sendMessage(String messageName);
  void resetStatistics();
  
  // ─── Spec Conversion ────────────────────────────────────────
  Future<void> convertMessageSpec(String xmlFolderPath);
}
```

### 11. Update Service (UpdateService)

Handles app auto-update via GitHub Releases.

```dart
/// Update service via GitHub Releases
class UpdateService {
  static const String owner = 'guruchun';
  static const String repo = 'mav-flow';
  
  /// Check for latest release
  static Future<UpdateInfo?> checkForUpdates(String currentVersion);
  
  /// Download update ZIP file
  static Future<String?> downloadUpdate(
    UpdateInfo updateInfo, {
    DownloadProgressCallback? onProgress,
  });
  
  /// Install downloaded update
  /// Creates batch script that waits for app exit, extracts files, restarts
  static Future<bool> installUpdate(String zipPath);
}

/// Update information model
class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool hasUpdate;
  final String releaseUrl;
  final String? zipDownloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;
}
```

---

## Data Flow

### Message Reception Flow

```
SerialPort
    │
    ▼ Byte stream
SerialCommunication.dataStream
    │
    ▼ MAVLink frames
MavlinkParser.parseBytes()
    │
    ▼ CRC validation
MavlinkParser.validateCrc()
    │  (CRC error → increment crcErrors, discard frame)
    ▼ Payload parsing
MavlinkParser.parsePayload()
    │
    ▼ Map<String, dynamic>
MavlinkState.updateFromReceivedMessage()
    │
    ▼ notifyListeners()
UI (ReceivePanel) refresh
```

### Message Transmission Flow

```
UI (SendPanel)
    │
    ▼ Field value input/edit
MavlinkState.updateSendValue()
    │
    ▼ Send button click
MavlinkState.sendMessage()
    │
    ▼ Collect field values from Data Table
MavlinkCodec.encode()
    │
    ▼ Uint8List (MAVLink binary)
SerialCommunication.send()
    │
    ▼ Increment txCount
SerialPort
```

---

## Interface Design

### MAVLink v2 Frame Structure

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

### Role Configuration File Format (role_config.json)

```json
{
  "roles": {
    "gcs": {
      "name": "GCS",
      "description": "Ground Control Station",
      "systemId": 255,
      "componentId": 0,
      "txMessages": ["HEARTBEAT", "COMMAND_LONG", "PARAM_REQUEST_READ"],
      "rxMessages": ["HEARTBEAT", "SYS_STATUS", "ATTITUDE", "GLOBAL_POSITION_INT"]
    },
    "fcc": {
      "name": "FCC",
      "description": "Flight Control Computer",
      "systemId": 1,
      "componentId": 3,
      "txMessages": ["HEARTBEAT", "ATTITUDE", "VFR_HUD"],
      "rxMessages": ["COMMAND_LONG", "SET_MODE"]
    },
    "mc": {
      "name": "MC",
      "description": "Mission Computer",
      "systemId": 1,
      "componentId": 2,
      "txMessages": ["HEARTBEAT", "ATTITUDE", "GLOBAL_POSITION_INT"],
      "rxMessages": ["COMMAND_LONG", "MISSION_ITEM"]
    },
    "gen3": {
      "name": "GEN3",
      "description": "DMI Gateway Gen3",
      "systemId": 1,
      "componentId": 1,
      "txMessages": ["HEARTBEAT", "SYS_STATUS", "POWER_STATUS"],
      "rxMessages": ["COMMAND_LONG", "PARAM_SET"]
    }
  }
}
```

### Message Specification Format (messages.json)

```json
{
  "messages": {
    "HEARTBEAT": {
      "id": 0,
      "name": "HEARTBEAT",
      "description": "The heartbeat message shows that a system is present",
      "crcExtra": 50,
      "fields": [
        {
          "name": "type",
          "type": "uint8_t",
          "description": "Vehicle or component type",
          "enum": "MAV_TYPE"
        },
        {
          "name": "autopilot",
          "type": "uint8_t",
          "description": "Autopilot type",
          "enum": "MAV_AUTOPILOT"
        }
      ]
    }
  },
  "enums": {
    "MAV_TYPE": {
      "name": "MAV_TYPE",
      "description": "MAVLINK component type",
      "isBitmask": false,
      "entries": [
        { "value": 0, "name": "GENERIC", "description": "Generic micro air vehicle" },
        { "value": 6, "name": "QUADROTOR", "description": "Quadrotor" }
      ]
    }
  }
}
```

---

## Screen Layout Design

### Main Screen Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│  [Role: ▼ GCS]    [Port: COM3 ▼]  [115200 ▼]  [Connect]  [⚙ Settings]  │
├────────────────────────────────┬────────────────────────────────────────┤
│                                │                                        │
│         RX Data Panel          │              TX Data Panel             │
│                                │                                        │
│  ┌──────────────────────────┐  │  ┌──────────────────────────────────┐  │
│  │ Message: [All        ▼]  │  │  │ Message: [HEARTBEAT ▼]           │  │
│  │ Search: [____________]   │  │  │ [Auto Send]  [Save] [Load]       │  │
│  ├──────────────────────────┤  │  ├──────────────────────────────────┤  │
│  │ Field         │Value│Unit│  │  │ Field      │ Value    │Unit│Desc│  │
│  │ HB.type       │QUAD │    │  │  │ type       │[▼ QUAD  ]│    │... │  │
│  │ HB.autopilot  │PX4  │    │  │  │ autopilot  │[▼ PX4   ]│    │... │  │
│  │ SYS.voltage   │12.4 │V   │  │  │ base_mode  │[89     ]│    │... │  │
│  │ ...           │...  │... │  │  │ ...        │...       │... │... │  │
│  └──────────────────────────┘  │  ├──────────────────────────────────┤  │
│                                │  │              [Send]               │  │
│                                │  ├──────────────────────────────────┤  │
│                                │  │ Auto Send:                        │  │
│                                │  │ ☑ HEARTBEAT   [500 ]ms           │  │
│                                │  │ ☐ SYS_STATUS  [1000]ms           │  │
│                                │  └──────────────────────────────────┘  │
├────────────────────────────────┴────────────────────────────────────────┤
│  ● Connected  │  RX: 1234  │  TX: 56  │  CRC Err: 2  │  10.0 Hz  │ GCS │
└─────────────────────────────────────────────────────────────────────────┘
```

### Settings Screen

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Settings                                                        [Back] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 🌙 Theme                                                        │   │
│  │    Light / Dark                                     [Toggle]    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 📋 Convert Message Spec                                         │   │
│  │    Convert MAVLink XML to JSON                      [Convert]   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 📊 Reset Statistics                                             │   │
│  │    Reset RX/TX counters                             [Reset]     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 🔄 Check for Updates                                            │   │
│  │    Current: v1.0.4                                  [Check]     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ℹ️ About                                                         │   │
│  │    MAV-Flow - MAVLink Message Transceiver                       │   │
│  │    Version 1.0.4                                                │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
lib/
├── main.dart                     # App entry point, version loading
├── models/
│   ├── app_settings.dart         # Theme settings
│   ├── auto_send_config.dart     # Auto send configuration
│   ├── data_table_entry.dart     # Data table entry model
│   ├── mavlink_frame.dart        # MAVLink frame structure
│   ├── mavlink_message_def.dart  # Message/field/enum definitions
│   ├── mavlink_state.dart        # Main app state
│   ├── role_config.dart          # Role configuration
│   └── update_info.dart          # Update information model
├── services/
│   ├── communication/
│   │   ├── communication_interface.dart  # Abstract interface
│   │   └── serial_communication.dart     # Serial implementation
│   ├── mavlink_codec.dart        # Message encoding
│   ├── mavlink_parser.dart       # Message parsing
│   ├── mavlink_spec_loader.dart  # XML→JSON conversion
│   └── update_service.dart       # GitHub release updates
├── screens/
│   └── main_screen.dart          # Main screen with Settings
├── theme/
│   └── app_theme.dart            # Light/Dark theme definitions
└── widgets/
    ├── receive_panel.dart        # RX data display
    ├── role_selector.dart        # Role dropdown
    ├── send_panel.dart           # TX data editing
    └── status_bar.dart           # Connection status display

assets/
├── mavlink/
│   ├── common.xml                # MAVLink standard XML (optional)
│   └── messages.json             # Runtime spec (auto-generated)
└── config/
    └── role_config.json          # Role definitions
```

---

## Error Handling

### Communication Errors

| Error Type | Handling |
|------------|----------|
| Port open failure | Show error SnackBar, reset connection state |
| Connection lost | Stop auto-send, update state, notify UI |
| Send failure | Show error SnackBar, provide retry option |

### Parsing Errors

| Error Type | Handling |
|------------|----------|
| CRC error | Increment crcErrors counter, discard frame, log warning |
| Unknown message ID | Log warning, discard frame |
| Payload size mismatch | Log error, discard frame |

### Spec Loading Errors

| Error Type | Handling |
|------------|----------|
| XML parse failure | Show error dialog, retain previous spec |
| JSON load failure | Attempt XML re-conversion at startup |
| Role config load failure | Use default role settings, show warning |

---

## Correctness Properties

### Property 1: TAG Format Consistency

*For any* MAVLink message field, the generated TAG shall always follow the `{MessageName}.{FieldName}` pattern with exactly one period (`.`) between message name and field name.

**Validates: FR-1.3, FR-7.3**

### Property 2: Message Serialization/Deserialization Round-trip

*For any* valid MAVLink message field value set, serializing with `MavlinkCodec.encode()` then deserializing with `MavlinkParser.parsePayload()` shall restore identical field values.

**Validates: FR-1.2, FR-2.4**

### Property 3: Role-based Message Filtering

*For any* selected role, the TX message list shown shall contain only messages defined in that role's `txMessages`, and no undefined messages shall appear.

**Validates: FR-3.2, FR-3.3**

### Property 4: Current/Send Value Independence

*For any* Data Table field, modifying `sendValue` shall not change `currentValue`, and receiving a new message that updates `currentValue` shall not change `sendValue`.

**Validates: FR-7.2**

### Property 5: MAVLink v2 Frame Synchronization

*For any* byte stream, a contiguous byte sequence starting with 0xFD (MAVLink v2 header) with valid length field shall be extracted as a complete MAVLink frame; incomplete frame data shall be retained in buffer for combination with next received data.

**Validates: FR-4.2**

---

## References

- [MAVLink Developer Guide](https://mavlink.io/en/)
- [MAVLink v2 Protocol](https://mavlink.io/en/guide/mavlink_version.html)
- [MAVLink Message Definitions (common.xml)](https://mavlink.io/en/messages/common.html)
- [CRC-16/MCRF4XX Algorithm](https://mavlink.io/en/guide/serialization.html#crc_extra)
- [Flutter Documentation](https://docs.flutter.dev/)

---

*Last updated: 2026-10-16*
