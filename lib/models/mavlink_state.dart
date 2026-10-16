import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auto_send_config.dart';
import 'data_table_entry.dart';
import 'mavlink_message_def.dart';
import 'role_config.dart';
import '../services/communication/communication_interface.dart';
import '../services/communication/serial_communication.dart';
import '../services/mavlink_codec.dart';
import '../services/mavlink_parser.dart';
import '../services/mavlink_spec_loader.dart';

/// App-wide state including MAVLink functionality
///
/// Manages role management, message spec, Data Table, communication, auto-send, etc.
class MavlinkState extends ChangeNotifier {
  // --- Role Management ---
  String _currentRoleId = 'gcs';
  Map<String, RoleConfig> _roleConfigs = {};
  List<String> _roleOrder = [];

  /// Currently selected role ID (empty string if not selected)
  String get currentRoleId => _currentRoleId;

  /// Checks if role is selected
  bool get isRoleSelected => _currentRoleId.isNotEmpty && _roleConfigs.containsKey(_currentRoleId);

  /// Available role list (UI display order)
  List<String> get availableRoleIds => _roleOrder;

  /// All loaded role configs
  Map<String, RoleConfig> get roleConfigs => _roleConfigs;

  /// Current role config
  RoleConfig get currentRoleConfig =>
      _roleConfigs[_currentRoleId] ??
      const RoleConfig(
        roleId: 'gcs',
        name: 'GCS',
        description: 'Ground Control Station',
        systemId: 255,
        componentId: 0,
        txMessages: [],
        rxMessages: [],
      );

  /// Changes role.
  void setRole(String roleId) {
    if (_currentRoleId != roleId && _roleConfigs.containsKey(roleId)) {
      _currentRoleId = roleId;
      _initializeDataTable();  // Reinitialize Data Table on role change
      initializeAutoSendConfigs();
      notifyListeners();
    }
  }

  /// Loads role configs.
  Future<void> loadRoleConfigs(String configPath) async {
    try {
      final result = await RoleConfigLoader.loadFromAsset(configPath);
      _roleConfigs = result.configs;
      _roleOrder = result.roleOrder;

      // Only load roles, don't select default (user selects directly)
      // Keep currentRoleId empty or don't set to first role
      _currentRoleId = ''; // Not selected state
    } catch (e) {
      debugPrint('Failed to load role configs: $e');
      _roleConfigs = {};
      _roleOrder = [];
      _currentRoleId = '';
    }
    notifyListeners();
  }

  // --- Message Spec ---
  MavlinkSpec? _spec;
  MavlinkParser? _parser;
  MavlinkCodec? _codec;

  MavlinkSpec? get spec => _spec;
  bool get isSpecLoaded => _spec != null;

  /// Loads message spec.
  Future<void> loadSpec(String jsonPath) async {
    try {
      _spec = await MavlinkSpecLoader.loadFromAssetJson(jsonPath);
      _parser = MavlinkParser(_spec!);
      _codec = MavlinkCodec(_spec!);
      _initializeDataTable();
    } catch (e) {
      debugPrint('Failed to load message spec: $e');
    }
    notifyListeners();
  }

  /// Converts XML to JSON.
  ///
  /// Converts only messages defined in role_config.json.
  Future<void> convertMessageSpec({
    required List<String> xmlPaths,
    required String outputJsonPath,
    required String roleConfigPath,
  }) async {
    try {
      // Extract required message names from role_config
      final messageNames =
          await MavlinkSpecLoader.extractMessageNamesFromRoleConfig(
              roleConfigPath);

      await MavlinkSpecLoader.convertXmlToJson(
        xmlPaths: xmlPaths,
        outputJsonPath: outputJsonPath,
        messageFilter: messageNames,
      );
      // Reload after conversion
      _spec = await MavlinkSpecLoader.loadFromFileJson(outputJsonPath);
      _parser = MavlinkParser(_spec!);
      _codec = MavlinkCodec(_spec!);
      _initializeDataTable();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to convert message spec: $e');
      rethrow;
    }
  }

  // --- Data Table ---
  final DataTable dataTable = DataTable();

  /// Initializes Data Table.
  void _initializeDataTable() {
    dataTable.clear();

    if (_spec == null) return;

    // Create Data Table entries for current role's TX/RX messages
    final roleConfig = currentRoleConfig;
    final messageNames = <String>{
      ...roleConfig.txMessages,
      ...roleConfig.rxMessages,
    };

    for (final messageName in messageNames) {
      final messageDef = _spec!.getMessageByName(messageName);
      if (messageDef == null) continue;

      for (final field in messageDef.fields) {
        final entry = DataTableEntry(
          tag: DataTableEntry.createTag(messageName, field.name),
          messageName: messageName,
          fieldName: field.name,
          dataType: field.type,
          units: field.units,
          description: field.description,
          enumName: field.enumName,
          arrayLength: field.arrayLength,
        );
        dataTable.addEntry(entry);
      }
    }
  }

  /// Updates Data Table from received message.
  void updateFromReceivedMessage(Map<String, dynamic> fields) {
    for (final entry in fields.entries) {
      dataTable.updateCurrentValue(entry.key, entry.value);
    }
    notifyListeners();
  }

  /// Updates send value.
  void updateSendValue(String tag, dynamic value) {
    dataTable.updateSendValue(tag, value);
    notifyListeners();
  }

  /// Copies current value to send value.
  void copyCurrentToSend(String messageName) {
    dataTable.copyCurrentToSendForMessage(messageName);
    notifyListeners();
  }

  /// Saves send values to JSON file.
  Future<void> saveSendValuesToFile(String filePath) async {
    await dataTable.saveSendValuesToFile(filePath);
  }

  /// Loads send values from JSON file.
  Future<void> loadSendValuesFromFile(String filePath) async {
    await dataTable.loadSendValuesFromFile(filePath);
    notifyListeners();
  }

  // --- Communication ---
  CommunicationInterface? _communication;
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _dataStreamSub;

  SerialConnectionState _connectionState = SerialConnectionState.disconnected;
  int _sequence = 0;

  // Statistics
  int _rxPacketCount = 0;
  int _txPacketCount = 0;
  final List<DateTime> _rxTimestamps = [];

  SerialConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == SerialConnectionState.connected;

  int get rxPacketCount => _rxPacketCount;
  int get txPacketCount => _txPacketCount;
  int get crcErrorCount => _parser?.crcErrors ?? 0;

  /// Calculates receive rate (Hz)
  double get rxRate {
    final now = DateTime.now();
    _rxTimestamps
        .removeWhere((t) => now.difference(t).inMilliseconds > 1000);
    return _rxTimestamps.length.toDouble();
  }

  /// Connects to serial port.
  Future<void> connect(SerialConfig config) async {
    if (_communication != null) {
      await disconnect();
    }

    _communication = SerialCommunication();

    // Subscribe to connection state
    _connectionStateSub = _communication!.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    // Subscribe to data stream
    _dataStreamSub = _communication!.dataStream.listen(_handleReceivedData);

    try {
      await _communication!.connect(config.toMap());
    } catch (e) {
      _connectionState = SerialConnectionState.error;
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnects.
  Future<void> disconnect() async {
    _autoSendManager?.stopAll();

    await _communication?.disconnect();
    await _connectionStateSub?.cancel();
    await _dataStreamSub?.cancel();

    _communication = null;
    _connectionStateSub = null;
    _dataStreamSub = null;
    _connectionState = SerialConnectionState.disconnected;

    notifyListeners();
  }

  /// Handles received data.
  void _handleReceivedData(Uint8List data) {
    if (_parser == null) return;

    final frames = _parser!.extractFrames(data);
    for (final frame in frames) {
      _rxPacketCount++;
      _rxTimestamps.add(DateTime.now());

      // Parse payload
      final fields = _parser!.parsePayload(frame);
      if (fields.isNotEmpty) {
        updateFromReceivedMessage(fields);
      }
    }
  }

  /// Sends message.
  Future<void> sendMessage(int messageId) async {
    if (!isConnected || _codec == null || _communication == null) return;

    final messageDef = _spec?.getMessage(messageId);
    if (messageDef == null) return;

    // Collect send values from Data Table
    final fieldValues = dataTable.getSendValuesForMessage(messageDef.name);

    try {
      final data = _codec!.encode(
        messageId: messageId,
        systemId: currentRoleConfig.systemId,
        componentId: currentRoleConfig.componentId,
        sequence: _sequence++ & 0xFF,
        fieldValues: fieldValues,
      );

      await _communication!.send(data);
      _txPacketCount++;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  /// Sends message by name.
  Future<void> sendMessageByName(String messageName) async {
    final messageDef = _spec?.getMessageByName(messageName);
    if (messageDef != null) {
      await sendMessage(messageDef.id);
    }
  }

  // --- Auto-send ---
  AutoSendManager? _autoSendManager;

  AutoSendManager get autoSendManager {
    _autoSendManager ??= AutoSendManager(
      onSendMessage: (messageId) => sendMessage(messageId),
    );
    return _autoSendManager!;
  }

  /// Toggles auto-send for message.
  void toggleAutoSend(int messageId) {
    autoSendManager.toggle(messageId);
    notifyListeners();
  }

  /// Sets auto-send interval.
  void setAutoSendInterval(int messageId, int intervalMs) {
    autoSendManager.setInterval(messageId, intervalMs);
    notifyListeners();
  }

  /// Initializes auto-send configs.
  void initializeAutoSendConfigs() {
    if (_spec == null) return;

    final roleConfig = currentRoleConfig;
    for (final messageName in roleConfig.txMessages) {
      final messageDef = _spec!.getMessageByName(messageName);
      if (messageDef != null) {
        final config = AutoSendConfig(
          messageId: messageDef.id,
          messageName: messageName,
        );
        autoSendManager.addConfig(config);
      }
    }
  }

  /// Stops all auto-sends.
  void stopAllAutoSend() {
    autoSendManager.stopAll();
    notifyListeners();
  }

  // --- Statistics Reset ---
  void resetStats() {
    _rxPacketCount = 0;
    _txPacketCount = 0;
    _rxTimestamps.clear();
    _parser?.resetStats();
    notifyListeners();
  }

  // --- Cleanup ---
  @override
  void dispose() {
    _autoSendManager?.dispose();
    _connectionStateSub?.cancel();
    _dataStreamSub?.cancel();
    _communication?.dispose();
    super.dispose();
  }
}
