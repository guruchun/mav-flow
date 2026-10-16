# MAV-Flow User Guide

This document provides detailed instructions for using MAV-Flow.

---

## Table of Contents

1. [Installation & Launch](#1-installation--launch)
2. [Screen Layout](#2-screen-layout)
3. [Role Configuration](#3-role-configuration)
4. [Serial Connection](#4-serial-connection)
5. [Receiving Messages (RX Data)](#5-receiving-messages-rx-data)
6. [Sending Messages (TX Data)](#6-sending-messages-tx-data)
7. [Auto Send Settings](#7-auto-send-settings)
8. [Settings Menu](#8-settings-menu)
9. [MAVLink XML Conversion](#9-mavlink-xml-conversion)
10. [Role Configuration File](#10-role-configuration-file)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Installation & Launch

### 1.1 Download

Download the latest version from [GitHub Releases](https://github.com/guruchun/mav-flow/releases/latest).

- Download `mav-flow-x.x.x-windows-x64.zip`
- Ignore Source code (zip/tar.gz) - these are source files

### 1.2 Installation

1. Extract the downloaded ZIP file to your desired folder
2. No installation process required - runs directly (portable)

### 1.3 Launch

Double-click `mav-flow.exe` to launch the application.

### 1.4 Updates

- App automatically checks for updates on startup
- Update notification banner appears when a new version is available
- Manual check available at Settings > Check for Updates

---

## 2. Screen Layout

### 2.1 Overall Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  [Update notification banner] (shown only when update available)│
├─────────────────────────────────────────────────────────────────┤
│  [Role ▼]  [Port ▼]  [Baud ▼]  [Connect]                [⚙]     │
├───────────────────────────┬─────────────────────────────────────┤
│       RX Data             │            TX Data                  │
│                           │                                     │
│  Message: [All ▼]         │  Message: [All ▼]                   │
│  Search: [____________]   │  Search: [____________]             │
│                           │                                     │
│  ┌─────────────────────┐  │  ┌─────────────────────────────┐    │
│  │ Field │ Value │Unit │  │  │ Field │ Value │Unit │ Desc  │    │
│  ├───────┼───────┼─────┤  │  ├───────┼───────┼─────┼───────┤    │
│  │ ...   │ ...   │ ... │  │  │ ...   │ [___] │ ... │ ...   │    │
│  └─────────────────────┘  │  └─────────────────────────────┘    │
│                           │                         [Send]      │
├───────────────────────────┴─────────────────────────────────────┤
│  ● Connected | RX: 1234 | TX: 56 | CRC Err: 0 | 10.0 Hz         │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Toolbar

| Element | Description |
|---------|-------------|
| Role | Select current role (GCS, FCC, MC, GEN3) |
| Port | Select serial port |
| Baud | Select baud rate (9600 ~ 921600) |
| Connect/Disconnect | Connect/disconnect serial port |
| ⚙ (Settings) | Open settings screen |

### 2.3 Status Bar

| Item | Description |
|------|-------------|
| ● Connected/Disconnected | Connection status |
| RX | Number of received packets |
| TX | Number of transmitted packets |
| CRC Errors | CRC error count (shown only when errors exist) |
| Hz | Current receive rate |
| Role | Currently selected role |

---

## 3. Role Configuration

### 3.1 What is a Role?

A Role defines what device this app represents in the MAVLink network.

### 3.2 Default Roles

| Role | System ID | Component ID | Description |
|------|-----------|--------------|-------------|
| GCS | 255 | 0 | Ground Control Station |
| FCC | 1 | 3 | Flight Control Computer |
| MC | 1 | 2 | Mission Computer |
| GEN3 | 1 | 1 | DMI Gateway Gen3 |

### 3.3 Messages per Role

Each role has different TX and RX message sets:

**GCS Role Example:**
- TX: HEARTBEAT, COMMAND_LONG, PARAM_REQUEST_READ, MISSION_REQUEST
- RX: HEARTBEAT, SYS_STATUS, ATTITUDE, GLOBAL_POSITION_INT, VFR_HUD

### 3.4 Selecting a Role

1. Click the Role dropdown in the toolbar
2. Select the desired role
3. RX/TX panel message lists automatically update

---

## 4. Serial Connection

### 4.1 Connection Settings

1. **Select Port**: Choose the COM port to use (e.g., COM3)
2. **Select Baud Rate**: Choose communication speed (default: 115200)
3. **Click Connect**: Start connection

### 4.2 Connection Status

| Status | Indicator | Description |
|--------|-----------|-------------|
| Disconnected | Grey ● | Not connected |
| Connecting | Orange ● | Connecting |
| Connected | Green ● | Connected |
| Error | Red ● | Error occurred |

### 4.3 Disconnecting

- Connect button changes to Disconnect
- Click Disconnect to close connection

---

## 5. Receiving Messages (RX Data)

### 5.1 RX Data Panel

The left panel displays field values of received MAVLink messages in real-time.

### 5.2 Message Filter

- **Message dropdown**: Show specific message only (All = show all)
- **Search box**: Search by field name/description

### 5.3 Table Columns

| Column | Description |
|--------|-------------|
| Field | Field name (MESSAGE.field format when All is selected) |
| Value | Current received value (Enum shown as name) |
| Unit | Unit (m/s, deg, etc.) |
| Description | Field description |

### 5.4 Enum Value Display

Enum type fields are displayed as names instead of numbers:
- Example: `6` → `QUADROTOR` (MAV_TYPE)

---

## 6. Sending Messages (TX Data)

### 6.1 TX Data Panel

The right panel allows editing and sending message field values.

### 6.2 Field Editing

| Field Type | Edit Method |
|------------|-------------|
| Number | Enter directly in text field |
| Enum | Select from dropdown |
| Bitmask | Click edit icon (🖊) → Select with checkboxes |

### 6.3 Bitmask Editing

1. Click the edit icon in the Unit column
2. Select/deselect checkboxes for each bit in the popup
3. Click OK to apply

### 6.4 Sending Messages

1. Select a message from the Message dropdown
2. Edit field values
3. Click **Send** button

> ⚠️ The Send button is only enabled when a specific message is selected and connected.

### 6.5 Save/Load TX Values

- **Save**: Save current TX values to JSON file
- **Load**: Load TX values from saved JSON file

---

## 7. Auto Send Settings

### 7.1 Auto Send List

Click the **Auto Send** button at the top of the TX Data panel to expand the auto send list.

### 7.2 Enabling Auto Send

1. Select checkbox for each message
2. Selected messages are automatically sent at the configured interval

### 7.3 Send Interval Setting

- Default interval: 500ms
- Individual interval can be set per message

---

## 8. Settings Menu

Click the ⚙ button in the toolbar to open the Settings screen.

### 8.1 Theme

- Switch between Light / Dark theme
- Toggle with switch

### 8.2 Convert Message Spec

- Convert MAVLink XML files to JSON
- See [9. MAVLink XML Conversion](#9-mavlink-xml-conversion)

### 8.3 Reset Statistics

- Reset RX/TX packet counters

### 8.4 Check for Updates

- Check for new versions
- Download and install if update available

---

## 9. MAVLink XML Conversion

Convert MAVLink standard XML files (common.xml, etc.) to JSON format used by the app.

### 9.1 Conversion Steps

1. Go to Settings > **Convert Message Spec** > Click Convert
2. Select the **folder** containing MAVLink XML files
3. All XML files are automatically scanned and converted

### 9.2 Conversion Rules

- Only messages defined in `role_config.json` are converted
- Output saved to `assets/mavlink/messages.json`
- New spec is automatically loaded after conversion

### 9.3 Download MAVLink XML

Official MAVLink XML files:
- https://github.com/mavlink/mavlink/tree/master/message_definitions/v1.0

---

## 10. Role Configuration File

### 10.1 File Location

`assets/config/role_config.json`

### 10.2 File Format

```json
{
  "roles": {
    "gcs": {
      "name": "GCS",
      "description": "Ground Control Station",
      "systemId": 255,
      "componentId": 0,
      "txMessages": ["HEARTBEAT", "COMMAND_LONG"],
      "rxMessages": ["HEARTBEAT", "SYS_STATUS", "ATTITUDE"]
    }
  }
}
```

### 10.3 Field Description

| Field | Description |
|-------|-------------|
| name | Role name displayed in UI |
| description | Role description |
| systemId | MAVLink System ID |
| componentId | MAVLink Component ID |
| txMessages | List of messages this role transmits |
| rxMessages | List of messages this role receives |

### 10.4 Adding/Modifying Roles

1. Edit `role_config.json` file
2. Restart the app
3. XML conversion may be needed if message specs are missing

---

## 11. Troubleshooting

### 11.1 Port Not Showing in List

- Check USB cable connection
- Verify COM port in Device Manager
- USB driver installation may be required

### 11.2 No Data Received After Connection

- Verify baud rate matches the device
- Check if the message is included in role's rxMessages
- Verify TX/RX cable connections

### 11.3 Many CRC Errors

- Possible baud rate mismatch
- Communication quality issues (cable, noise)

### 11.4 Send Button is Disabled

- Check serial connection status
- Select a specific message from dropdown (disabled when All is selected)

### 11.5 Message Not Found in messages.json

- Convert XML via Settings > Convert Message Spec
- Add the message to txMessages/rxMessages in `role_config.json`

---

## Appendix: Keyboard Shortcuts

| Shortcut | Function |
|----------|----------|
| (None currently) | - |

---

*Last updated: 2026-10-16*
