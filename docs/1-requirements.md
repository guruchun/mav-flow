# MAV-Flow Requirements Specification

## Overview

MAV-Flow is a Flutter Windows Desktop application for MAVLink protocol-based message transmission and reception. It extends serial monitoring functionality to support the MAVLink standard, enabling message communication for various device roles (GCS, FCC, MC, GEN3).

---

## Functional Requirements

### FR-1: MAVLink Message Reception and Parsing

**FR-1.1**: The system shall receive MAVLink v2 protocol format binary messages via serial port.

**FR-1.2**: Received MAVLink messages shall be parsed according to message ID, and parsed field values shall be updated in the Data Table.

**FR-1.3**: Each parsed field shall be identified by a TAG in the format `{MessageName}.{FieldName}` (e.g., `HEARTBEAT.type`, `SYS_STATUS.voltage_battery`).

**FR-1.4**: The receive screen shall display Data Table values in real-time, showing field name, value, unit, and description according to MAVLink message specifications.

**FR-1.5**: Enum type fields shall display the enum name instead of numeric value (e.g., `6` → `QUADROTOR` for MAV_TYPE).

**FR-1.6**: Bitmask type fields shall display as hex values with expandable bit details.

---

### FR-2: MAVLink Message Generation and Transmission

**FR-2.1**: Users shall be able to select a MAVLink message to transmit from a list on the send screen.

**FR-2.2**: The selected message's field values shall be read from the Data Table and displayed on the send screen.

**FR-2.3**: Users shall be able to directly modify each field's value on the send screen.

**FR-2.4**: When the Send button is pressed, a MAVLink message shall be generated with current field values and transmitted via serial port.

**FR-2.5**: When auto-send is enabled, messages shall be repeatedly transmitted at the configured interval (default 500ms).

**FR-2.6**: Auto-send interval shall be user-configurable per message.

**FR-2.7**: TX values shall be saveable to and loadable from JSON files.

---

### FR-3: Role-Based Message Configuration

**FR-3.1**: The system shall support 4 device roles: `GCS`, `FCC`, `MC`, `GEN3`.

**FR-3.2**: A configuration file shall define TX message list and RX message list for each role.

**FR-3.3**: Users shall be able to select the current role from the toolbar, and the available TX/RX message lists shall be determined by the selected role.

**FR-3.4**: Each role shall have a configurable System ID and Component ID.

---

### FR-4: Communication Interface

**FR-4.1**: The current version supports serial communication only.

**FR-4.2**: The system shall implement MAVLink frame synchronization (0xFD header) and transmission functionality.

**FR-4.3**: The communication interface shall be abstracted to allow future TCP/UDP communication extensions.

**FR-4.4**: The system shall track and display CRC errors.

---

### FR-5: MAVLink Message Specification Management

**FR-5.1**: MAVLink standard XML files (common.xml, etc.) shall be used as the source of message specifications.

**FR-5.2**: Extended/custom messages shall also be managed in MAVLink XML format.

**FR-5.3**: At conversion time, XML files shall be parsed and converted to JSON format; at runtime, only JSON shall be referenced.

**FR-5.4**: A "Convert Message Spec" button shall be provided in Settings to re-parse XML and update JSON.

**FR-5.5**: Only messages defined in `role_config.json` shall be included in the converted JSON.

---

### FR-6: Screen Layout

**FR-6.1**: A role (device) selection dropdown shall be placed in the toolbar.

**FR-6.2**: The main area shall be split left/right to display receive and send screens simultaneously.

**FR-6.3**: The receive screen shall display received MAVLink message field values in Data Table format.

**FR-6.4**: The send screen shall provide:
  - Message selection (display all data or selected message data only)
  - Data Table view and field value editing
  - Manual send button
  - Auto-send message list with interval and ON/OFF control
  - Save/Load TX values functionality

**FR-6.5**: A status bar shall display connection status, RX/TX packet counts, CRC errors, receive rate (Hz), and current role.

---

### FR-7: Data Table Design

**FR-7.1**: Receive and send screens shall share the same Data Table structure.

**FR-7.2**: Each field shall maintain separate current value (received) and send value (user-modified).

**FR-7.3**: Data Table TAGs shall use the format `{MessageName}.{FieldName}`.

---

### FR-8: Theme and Settings

**FR-8.1**: The system shall support Light and Dark themes.

**FR-8.2**: Theme selection shall persist across app restarts.

**FR-8.3**: Statistics (RX/TX counts, CRC errors) shall be resettable.

---

### FR-9: Auto Update

**FR-9.1**: The app shall check for updates via GitHub Releases API on startup.

**FR-9.2**: When a new version is available, an update notification banner shall be displayed.

**FR-9.3**: Users shall be able to manually check for updates in Settings.

**FR-9.4**: The update process shall download the ZIP file, wait for app exit, extract to app directory, and restart the app.

---

## Non-Functional Requirements

### NFR-1: Performance

**NFR-1.1**: MAVLink message reception and parsing shall not block the UI (background processing).

**NFR-1.2**: Auto-send timers shall maintain the specified interval within ±10ms.

**NFR-1.3**: UI updates shall maintain smooth scrolling and responsiveness during high message rates.

---

### NFR-2: Extensibility

**NFR-2.1**: The communication interface shall provide an abstraction layer for future TCP/UDP additions.

**NFR-2.2**: When adding new MAVLink messages, only XML files and role configuration need to be modified.

---

### NFR-3: Maintainability

**NFR-3.1**: MAVLink message specifications shall use the standard MAVLink XML format to maintain compatibility with official documentation.

**NFR-3.2**: Role-specific message settings shall be managed in a separate configuration file.

---

### NFR-4: Usability

**NFR-4.1**: The app shall be portable (no installation required).

**NFR-4.2**: Field editing shall support appropriate input methods per data type (text fields, dropdowns, bitmask editors).

---

## Terminology

| Term | Description |
|------|-------------|
| MAVLink | Micro Air Vehicle Link - lightweight communication protocol for drones and unmanned systems |
| MAVLink v2 | MAVLink protocol version 2, uses header byte 0xFD |
| GEN3 | Communication Gateway 3rd generation (data collection, protocol conversion, message routing) |
| MC | Mission Computer role |
| FCC | Flight Control Computer role |
| GCS | Ground Control Station role |
| Data Table | Internal data structure storing current and send values for message fields |
| TAG | String uniquely identifying a field (`{MessageName}.{FieldName}` format) |
| CRC Extra | Additional byte used in MAVLink CRC calculation, unique per message type |

---

## Constraints

1. Current version supports serial communication only; TCP/UDP will be added in future versions.
2. Windows Desktop platform only (x64).
3. Requires serial port (including USB-to-Serial adapters).

---

## Use Cases

This application can run multiple instances simultaneously, with each instance representing one device (role). This enables testing a real hardware device by simulating its peripheral devices with this application.

**Example Setup:**
- Instance 1: GEN3 role (real hardware device)
- Instance 2: FCC role (simulation)
- Instance 3: GCS role (simulation)

This configuration allows verification of real device behavior by simulating the surrounding MAVLink network.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-10-09 | Initial release |
| 1.0.1 | 2026-10-15 | Added documentation, use app version from pubspec |
| 1.0.2 | 2026-10-16 | Translated all comments/messages to English |
| 1.0.3 | 2026-10-16 | Fixed auto-update file replacement and restart |
| 1.0.4 | 2026-10-16 | Fixed Settings screen version display |

