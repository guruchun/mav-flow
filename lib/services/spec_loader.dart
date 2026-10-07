import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// YAML 규격 파일을 로딩하여 Map 구조로 반환한다.
///
/// Python의 load_spec()에 대응한다.
/// Flutter assets에 번들된 message_spec.yaml을 로딩한다.
Future<Map<String, dynamic>> loadSpec() async {
  final raw = await rootBundle.loadString('assets/message_spec.yaml');
  final yamlDoc = loadYaml(raw);
  return _convertYamlMap(yamlDoc) as Map<String, dynamic>;
}

/// YamlMap / YamlList를 Dart 표준 타입(Map/List)으로 재귀 변환한다.
dynamic _convertYamlMap(dynamic value) {
  if (value is YamlMap) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (e) => MapEntry(e.key.toString(), _convertYamlMap(e.value)),
      ),
    );
  } else if (value is YamlList) {
    return value.map(_convertYamlMap).toList();
  }
  return value;
}
