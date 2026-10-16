import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

/// Role-based message configuration
///
/// Loaded from role_config.json, contains role ID, name, description,
/// system/component ID, and TX/RX message lists.
class RoleConfig {
  /// Role ID (JSON key, e.g., "gen3", "mc", "fcc", "gcs")
  final String roleId;

  /// Role display name (e.g., "GEN3", "MC")
  final String name;

  /// Role description (e.g., "DMI Gateway Gen3")
  final String description;

  /// System ID (1-255)
  final int systemId;

  /// Component ID (0-255)
  final int componentId;

  /// List of transmittable message names
  final List<String> txMessages;

  /// List of receivable message names
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

  /// Creates from JSON
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

  /// Converts to JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'systemId': systemId,
        'componentId': componentId,
        'txMessages': txMessages,
        'rxMessages': rxMessages,
      };

  /// Checks if message can be transmitted
  bool canTransmit(String messageName) => txMessages.contains(messageName);

  /// Checks if message should be received
  bool shouldReceive(String messageName) => rxMessages.contains(messageName);

  @override
  String toString() =>
      'RoleConfig(id: $roleId, name: $name, sysId: $systemId, compId: $componentId)';
}

/// Role configuration loader
class RoleConfigLoader {
  /// Loads role configuration from assets.
  ///
  /// Returns: RoleConfig map keyed by roleId and role ID order list
  static Future<RoleConfigResult> loadFromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    return _parseJson(jsonString);
  }

  /// Loads role configuration from file.
  static Future<RoleConfigResult> loadFromFile(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    return _parseJson(jsonString);
  }

  /// Parses JSON string.
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

  /// Default GCS configuration
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

  /// Saves default configuration to JSON file.
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

/// Role configuration load result
class RoleConfigResult {
  /// RoleConfig map keyed by roleId
  final Map<String, RoleConfig> configs;

  /// Role order as defined in JSON (for UI display)
  final List<String> roleOrder;

  const RoleConfigResult({
    required this.configs,
    required this.roleOrder,
  });

  /// Returns first role ID (for default selection)
  String get defaultRoleId => roleOrder.isNotEmpty ? roleOrder.first : 'gcs';

  /// Gets config by role ID
  RoleConfig? getConfig(String roleId) => configs[roleId];
}
