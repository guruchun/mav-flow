import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

/// 역할별 메시지 설정
///
/// role_config.json에서 로드되며, 역할 ID와 이름, 설명,
/// 시스템/컴포넌트 ID, 송수신 메시지 목록을 포함합니다.
class RoleConfig {
  /// 역할 ID (JSON 키, 예: "gen3", "mc", "fcc", "gcs")
  final String roleId;

  /// 역할 표시 이름 (예: "GEN3", "MC")
  final String name;

  /// 역할 설명 (예: "DMI Gateway Gen3")
  final String description;

  /// 시스템 ID (1-255)
  final int systemId;

  /// 컴포넌트 ID (0-255)
  final int componentId;

  /// 송신 가능한 메시지 이름 목록
  final List<String> txMessages;

  /// 수신할 메시지 이름 목록
  final List<String> rxMessages;

  const RoleConfig({
    required this.roleId,
    required this.name,
    required this.description,
    required this.systemId,
    required this.componentId,
    required this.txMessages,
    required this.rxMessages,
  });

  /// JSON에서 생성
  factory RoleConfig.fromJson(String roleId, Map<String, dynamic> json) {
    return RoleConfig(
      roleId: roleId,
      name: json['name'] as String? ?? roleId.toUpperCase(),
      description: json['description'] as String? ?? roleId,
      systemId: json['systemId'] as int? ?? 1,
      componentId: json['componentId'] as int? ?? 1,
      txMessages: (json['txMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rxMessages: (json['rxMessages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'systemId': systemId,
        'componentId': componentId,
        'txMessages': txMessages,
        'rxMessages': rxMessages,
      };

  /// 메시지가 송신 가능한지 확인
  bool canTransmit(String messageName) => txMessages.contains(messageName);

  /// 메시지가 수신 대상인지 확인
  bool shouldReceive(String messageName) => rxMessages.contains(messageName);

  @override
  String toString() =>
      'RoleConfig(id: $roleId, name: $name, sysId: $systemId, compId: $componentId)';
}

/// 역할 설정 로더
class RoleConfigLoader {
  /// Assets에서 역할 설정을 로드합니다.
  ///
  /// 반환값: roleId를 키로 하는 RoleConfig 맵과 역할 ID 순서 목록
  static Future<RoleConfigResult> loadFromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    return _parseJson(jsonString);
  }

  /// 파일에서 역할 설정을 로드합니다.
  static Future<RoleConfigResult> loadFromFile(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    return _parseJson(jsonString);
  }

  /// JSON 문자열을 파싱합니다.
  static RoleConfigResult _parseJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final roles = json['roles'] as Map<String, dynamic>?;

    if (roles == null || roles.isEmpty) {
      return RoleConfigResult(
        configs: {'gcs': _defaultGcsConfig()},
        roleOrder: ['gcs'],
      );
    }

    final configs = <String, RoleConfig>{};
    final roleOrder = <String>[];

    for (final entry in roles.entries) {
      final roleId = entry.key;
      configs[roleId] =
          RoleConfig.fromJson(roleId, entry.value as Map<String, dynamic>);
      roleOrder.add(roleId);
    }

    return RoleConfigResult(configs: configs, roleOrder: roleOrder);
  }

  /// 기본 GCS 설정
  static RoleConfig _defaultGcsConfig() {
    return const RoleConfig(
      roleId: 'gcs',
      name: 'GCS',
      description: 'Ground Control Station',
      systemId: 255,
      componentId: 0,
      txMessages: ['HEARTBEAT', 'COMMAND_LONG'],
      rxMessages: ['HEARTBEAT', 'SYS_STATUS', 'ATTITUDE'],
    );
  }

  /// 기본 설정을 JSON 파일로 저장합니다.
  static Future<void> saveDefaultConfig(String filePath) async {
    final json = {
      'roles': {
        'gen3': const RoleConfig(
          roleId: 'gen3',
          name: 'GEN3',
          description: 'DMI Gateway Gen3',
          systemId: 1,
          componentId: 1,
          txMessages: ['HEARTBEAT', 'SYS_STATUS', 'POWER_STATUS'],
          rxMessages: ['HEARTBEAT', 'COMMAND_LONG', 'PARAM_SET'],
        ).toJson(),
        'mc': const RoleConfig(
          roleId: 'mc',
          name: 'MC',
          description: 'Mission Computer',
          systemId: 1,
          componentId: 2,
          txMessages: ['HEARTBEAT', 'ATTITUDE', 'GLOBAL_POSITION_INT'],
          rxMessages: ['HEARTBEAT', 'COMMAND_LONG', 'MISSION_ITEM'],
        ).toJson(),
        'fcc': const RoleConfig(
          roleId: 'fcc',
          name: 'FCC',
          description: 'Flight Control Computer',
          systemId: 1,
          componentId: 3,
          txMessages: ['HEARTBEAT', 'ATTITUDE', 'VFR_HUD', 'GLOBAL_POSITION_INT'],
          rxMessages: ['HEARTBEAT', 'COMMAND_LONG', 'SET_MODE', 'MANUAL_CONTROL'],
        ).toJson(),
        'gcs': const RoleConfig(
          roleId: 'gcs',
          name: 'GCS',
          description: 'Ground Control Station',
          systemId: 255,
          componentId: 0,
          txMessages: ['HEARTBEAT', 'COMMAND_LONG', 'PARAM_REQUEST_READ', 'MISSION_REQUEST'],
          rxMessages: ['HEARTBEAT', 'SYS_STATUS', 'ATTITUDE', 'GLOBAL_POSITION_INT', 'VFR_HUD'],
        ).toJson(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(json);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonString);
  }
}

/// 역할 설정 로드 결과
class RoleConfigResult {
  /// roleId를 키로 하는 RoleConfig 맵
  final Map<String, RoleConfig> configs;

  /// JSON에 정의된 역할 순서 (UI 표시용)
  final List<String> roleOrder;

  const RoleConfigResult({
    required this.configs,
    required this.roleOrder,
  });

  /// 첫 번째 역할 ID 반환 (기본 선택용)
  String get defaultRoleId => roleOrder.isNotEmpty ? roleOrder.first : 'gcs';

  /// 역할 ID로 설정 조회
  RoleConfig? getConfig(String roleId) => configs[roleId];
}
