import 'dart:async';
import 'dart:typed_data';

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

/// MAVLink 기능을 포함한 앱 전역 상태
///
/// 역할 관리, 메시지 규격, Data Table, 통신, 자동 전송 등을 관리합니다.
class MavlinkState extends ChangeNotifier {
  // ─── 역할 관리 ───────────────────────────────────────────────
  String _currentRoleId = 'gcs';
  Map<String, RoleConfig> _roleConfigs = {};
  List<String> _roleOrder = [];

  /// 현재 선택된 역할 ID (빈 문자열이면 선택 안 됨)
  String get currentRoleId => _currentRoleId;

  /// 역할이 선택되었는지 확인
  bool get isRoleSelected => _currentRoleId.isNotEmpty && _roleConfigs.containsKey(_currentRoleId);

  /// 사용 가능한 역할 목록 (UI 표시 순서)
  List<String> get availableRoleIds => _roleOrder;

  /// 로드된 모든 역할 설정
  Map<String, RoleConfig> get roleConfigs => _roleConfigs;

  /// 현재 역할 설정
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

  /// 역할을 변경합니다.
  void setRole(String roleId) {
    if (_currentRoleId != roleId && _roleConfigs.containsKey(roleId)) {
      _currentRoleId = roleId;
      _initializeDataTable();  // 역할 변경 시 Data Table 재초기화
      initializeAutoSendConfigs();
      notifyListeners();
    }
  }

  /// 역할 설정을 로드합니다.
  Future<void> loadRoleConfigs(String configPath) async {
    try {
      final result = await RoleConfigLoader.loadFromAsset(configPath);
      _roleConfigs = result.configs;
      _roleOrder = result.roleOrder;

      // 역할만 로드하고, 기본 역할 선택은 하지 않음 (사용자가 직접 선택)
      // currentRoleId는 빈 상태로 유지하거나 첫 번째 역할로 설정하지 않음
      _currentRoleId = ''; // 선택되지 않은 상태
    } catch (e) {
      debugPrint('역할 설정 로드 실패: $e');
      _roleConfigs = {};
      _roleOrder = [];
      _currentRoleId = '';
    }
    notifyListeners();
  }

  // ─── 메시지 규격 ─────────────────────────────────────────────
  MavlinkSpec? _spec;
  MavlinkParser? _parser;
  MavlinkCodec? _codec;

  MavlinkSpec? get spec => _spec;
  bool get isSpecLoaded => _spec != null;

  /// 메시지 규격을 로드합니다.
  Future<void> loadSpec(String jsonPath) async {
    try {
      _spec = await MavlinkSpecLoader.loadFromAssetJson(jsonPath);
      _parser = MavlinkParser(_spec!);
      _codec = MavlinkCodec(_spec!);
      _initializeDataTable();
    } catch (e) {
      debugPrint('메시지 규격 로드 실패: $e');
    }
    notifyListeners();
  }

  /// XML을 JSON으로 변환합니다.
  ///
  /// role_config.json에 정의된 메시지만 변환합니다.
  Future<void> convertMessageSpec({
    required List<String> xmlPaths,
    required String outputJsonPath,
    required String roleConfigPath,
  }) async {
    try {
      // role_config에서 필요한 메시지 이름 추출
      final messageNames =
          await MavlinkSpecLoader.extractMessageNamesFromRoleConfig(
              roleConfigPath);

      await MavlinkSpecLoader.convertXmlToJson(
        xmlPaths: xmlPaths,
        outputJsonPath: outputJsonPath,
        messageFilter: messageNames,
      );
      // 변환 후 다시 로드
      _spec = await MavlinkSpecLoader.loadFromFileJson(outputJsonPath);
      _parser = MavlinkParser(_spec!);
      _codec = MavlinkCodec(_spec!);
      _initializeDataTable();
      notifyListeners();
    } catch (e) {
      debugPrint('메시지 규격 변환 실패: $e');
      rethrow;
    }
  }

  // ─── Data Table ─────────────────────────────────────────────
  final DataTable dataTable = DataTable();

  /// Data Table을 초기화합니다.
  void _initializeDataTable() {
    dataTable.clear();

    if (_spec == null) return;

    // 현재 역할의 송수신 메시지에 대해 Data Table 항목 생성
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

  /// 수신 메시지로 Data Table을 업데이트합니다.
  void updateFromReceivedMessage(Map<String, dynamic> fields) {
    for (final entry in fields.entries) {
      dataTable.updateCurrentValue(entry.key, entry.value);
    }
    notifyListeners();
  }

  /// 전송값을 업데이트합니다.
  void updateSendValue(String tag, dynamic value) {
    dataTable.updateSendValue(tag, value);
    notifyListeners();
  }

  /// 현재값을 전송값으로 복사합니다.
  void copyCurrentToSend(String messageName) {
    dataTable.copyCurrentToSendForMessage(messageName);
    notifyListeners();
  }

  /// 전송값을 JSON 파일로 저장합니다.
  Future<void> saveSendValuesToFile(String filePath) async {
    await dataTable.saveSendValuesToFile(filePath);
  }

  /// JSON 파일에서 전송값을 로드합니다.
  Future<void> loadSendValuesFromFile(String filePath) async {
    await dataTable.loadSendValuesFromFile(filePath);
    notifyListeners();
  }

  // ─── 통신 ───────────────────────────────────────────────────
  CommunicationInterface? _communication;
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _dataStreamSub;

  SerialConnectionState _connectionState = SerialConnectionState.disconnected;
  int _sequence = 0;

  // 통계
  int _rxPacketCount = 0;
  int _txPacketCount = 0;
  final List<DateTime> _rxTimestamps = [];

  SerialConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == SerialConnectionState.connected;

  int get rxPacketCount => _rxPacketCount;
  int get txPacketCount => _txPacketCount;
  int get crcErrorCount => _parser?.crcErrors ?? 0;

  /// 수신율 (Hz) 계산
  double get rxRate {
    final now = DateTime.now();
    _rxTimestamps
        .removeWhere((t) => now.difference(t).inMilliseconds > 1000);
    return _rxTimestamps.length.toDouble();
  }

  /// 시리얼 포트에 연결합니다.
  Future<void> connect(SerialConfig config) async {
    if (_communication != null) {
      await disconnect();
    }

    _communication = SerialCommunication();

    // 연결 상태 구독
    _connectionStateSub = _communication!.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    // 데이터 스트림 구독
    _dataStreamSub = _communication!.dataStream.listen(_handleReceivedData);

    try {
      await _communication!.connect(config.toMap());
    } catch (e) {
      _connectionState = SerialConnectionState.error;
      notifyListeners();
      rethrow;
    }
  }

  /// 연결을 해제합니다.
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

  /// 수신된 데이터를 처리합니다.
  void _handleReceivedData(Uint8List data) {
    if (_parser == null) return;

    final frames = _parser!.extractFrames(data);
    for (final frame in frames) {
      _rxPacketCount++;
      _rxTimestamps.add(DateTime.now());

      // 페이로드 파싱
      final fields = _parser!.parsePayload(frame);
      if (fields.isNotEmpty) {
        updateFromReceivedMessage(fields);
      }
    }
  }

  /// 메시지를 전송합니다.
  Future<void> sendMessage(int messageId) async {
    if (!isConnected || _codec == null || _communication == null) return;

    final messageDef = _spec?.getMessage(messageId);
    if (messageDef == null) return;

    // Data Table에서 전송값 수집
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
      debugPrint('메시지 전송 실패: $e');
    }
  }

  /// 메시지 이름으로 전송합니다.
  Future<void> sendMessageByName(String messageName) async {
    final messageDef = _spec?.getMessageByName(messageName);
    if (messageDef != null) {
      await sendMessage(messageDef.id);
    }
  }

  // ─── 자동 전송 ───────────────────────────────────────────────
  AutoSendManager? _autoSendManager;

  AutoSendManager get autoSendManager {
    _autoSendManager ??= AutoSendManager(
      onSendMessage: (messageId) => sendMessage(messageId),
    );
    return _autoSendManager!;
  }

  /// 메시지의 자동 전송을 토글합니다.
  void toggleAutoSend(int messageId) {
    autoSendManager.toggle(messageId);
    notifyListeners();
  }

  /// 자동 전송 주기를 설정합니다.
  void setAutoSendInterval(int messageId, int intervalMs) {
    autoSendManager.setInterval(messageId, intervalMs);
    notifyListeners();
  }

  /// 자동 전송 설정을 초기화합니다.
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

  /// 모든 자동 전송을 중지합니다.
  void stopAllAutoSend() {
    autoSendManager.stopAll();
    notifyListeners();
  }

  // ─── 통계 초기화 ─────────────────────────────────────────────
  void resetStats() {
    _rxPacketCount = 0;
    _txPacketCount = 0;
    _rxTimestamps.clear();
    _parser?.resetStats();
    notifyListeners();
  }

  // ─── 정리 ───────────────────────────────────────────────────
  @override
  void dispose() {
    _autoSendManager?.dispose();
    _connectionStateSub?.cancel();
    _dataStreamSub?.cancel();
    _communication?.dispose();
    super.dispose();
  }
}
