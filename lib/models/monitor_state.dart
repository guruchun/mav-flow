import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/packet_parser.dart';
import '../services/serial_service.dart';
import '../services/spec_loader.dart';
import 'field_value.dart';

/// 애플리케이션 전체 상태를 관리하는 ChangeNotifier Provider.
///
/// Python MainWindow의 상태 변수 + 로직을 Dart/Flutter 방식으로 대응한다.
class MonitorState extends ChangeNotifier {
  // ─── YAML 스펙 / 파서 ──────────────────────────────────────────────
  Map<String, dynamic>? spec;
  PacketParser? parser;
  String? specError;

  // ─── 시리얼 서비스 ─────────────────────────────────────────────────
  SerialService? _serialService;
  StreamSubscription<SerialEvent>? _eventSub;

  // ─── 연결 상태 ─────────────────────────────────────────────────────
  bool isConnected = false;

  // ─── 통계 ──────────────────────────────────────────────────────────
  int packetCount = 0;
  int crcErrorCount = 0;
  final List<DateTime> _rateTimestamps = [];
  double packetRate = 0.0;

  // ─── 필드 데이터 ───────────────────────────────────────────────────
  /// 모든 필드 행 (필터링 원본 데이터)
  final List<FieldRow> allFields = [];

  /// 현재 필터/검색이 적용된 필드 행
  List<FieldRow> filteredFields = [];

  // ─── 필터 상태 ─────────────────────────────────────────────────────
  String filterType = 'All'; // 'All', 'Base', 'FuelCell', 'Cells'
  String searchText = '';

  // ─── 초기화 ────────────────────────────────────────────────────────
  MonitorState() {
    _loadSpec();
  }

  Future<void> _loadSpec() async {
    try {
      spec = await loadSpec();
      parser = PacketParser(spec!);
      _serialService = SerialService(spec!);
      _populateFieldsFromSpec();
    } catch (e) {
      specError = e.toString();
    }
    notifyListeners();
  }

  /// YAML 규격에서 모든 필드를 추출하여 allFields를 채운다.
  /// Python _populate_table_from_spec()에 대응한다.
  void _populateFieldsFromSpec() {
    allFields.clear();
    final messages = spec!['messages'] as Map<String, dynamic>;

    for (final msgEntry in messages.entries) {
      final msgName = msgEntry.key;
      final msgInfo = msgEntry.value as Map<String, dynamic>;
      final groups = msgInfo['groups'] as Map<String, dynamic>;

      for (final groupEntry in groups.entries) {
        final groupInfo = groupEntry.value as Map<String, dynamic>;
        final fields = groupInfo['fields'] as List<dynamic>;

        for (final fieldDef in fields) {
          final field = fieldDef as Map<String, dynamic>;
          final name = field['name'] as String;
          final type = field['type'] as String;
          final scale = field['scale_factor'];
          final offset = field['dmi_offset'];

          if (type.endsWith('_array')) {
            final count = field['count'] as int;
            final baseType = type.replaceAll('_array', '');
            for (int i = 0; i < count; i++) {
              allFields.add(FieldRow(
                name: '$name[$i]',
                messageType: msgName,
                dataType: baseType,
                scale: scale.toString(),
                offset: offset.toString(),
              ));
            }
          } else {
            allFields.add(FieldRow(
              name: name,
              messageType: msgName,
              dataType: type,
              scale: scale.toString(),
              offset: offset.toString(),
            ));
          }
        }
      }
    }
    applyFilter();
  }

  // ─── 포트 목록 ─────────────────────────────────────────────────────
  List<String> get availablePorts => SerialService.availablePorts();

  // ─── 시리얼 제어 ───────────────────────────────────────────────────
  void openPort({
    required String portName,
    required int baudrate,
    String parity = 'None',
    int databits = 8,
    int stopbits = 1,
    String flowcontrol = 'None',
  }) {
    if (_serialService == null) return;

    _eventSub?.cancel();
    _eventSub = _serialService!.events.listen(_onSerialEvent);

    _serialService!.openPort(
      portName: portName,
      baudrate: baudrate,
      parity: parity,
      databits: databits,
      stopbits: stopbits,
      flowcontrol: flowcontrol,
    );
  }

  void closePort() {
    _serialService?.closePort();
  }

  void _onSerialEvent(SerialEvent event) {
    switch (event) {
      case SerialConnected():
        isConnected = true;
        notifyListeners();
      case SerialDisconnected():
        isConnected = false;
        notifyListeners();
      case SerialError(:final message):
        isConnected = false;
        _lastError = message;
        notifyListeners();
      case SerialPacket(:final data):
        _onPacketReceived(data);
    }
  }

  String? _lastError;
  String? get lastError {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  // ─── 패킷 처리 ─────────────────────────────────────────────────────
  void _onPacketReceived(Uint8List rawPacket) {
    if (parser == null) return;

    if (!parser!.validateFrame(rawPacket)) {
      crcErrorCount++;
      notifyListeners();
      return;
    }

    packetCount++;

    // 수신율 계산 (최근 5초 기준)
    final now = DateTime.now();
    _rateTimestamps.add(now);
    final cutoff = now.subtract(const Duration(seconds: 5));
    _rateTimestamps.removeWhere((t) => t.isBefore(cutoff));
    if (_rateTimestamps.length >= 2) {
      final elapsed = _rateTimestamps.last
          .difference(_rateTimestamps.first)
          .inMilliseconds /
          1000.0;
      packetRate = elapsed > 0 ? (_rateTimestamps.length - 1) / elapsed : 0.0;
    }

    // 페이로드 파싱: rawPacket[1..-2]
    final payload = Uint8List.sublistView(rawPacket, 1, rawPacket.length - 2);
    final fieldValues = parser!.parsePayload(payload);

    // allFields 갱신 (이름 기반 매핑)
    final valueMap = <String, FieldValue>{
      for (final fv in fieldValues) fv.name: fv,
    };

    bool changed = false;
    for (final row in allFields) {
      final fv = valueMap[row.name];
      if (fv != null) {
        row.raw = fv.rawValue.toString();
        row.converted = _formatConverted(fv.convertedValue);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Python f"{val:.3f}".rstrip('0').rstrip('.') 와 동일한 포맷
  static String _formatConverted(double val) {
    String s = val.toStringAsFixed(3);
    // 소수점 뒤 trailing zero 제거
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ─── 필터 / 검색 ───────────────────────────────────────────────────
  void setFilterType(String type) {
    filterType = type;
    applyFilter();
  }

  void setSearchText(String text) {
    searchText = text.toLowerCase();
    applyFilter();
  }

  void applyFilter() {
    filteredFields = allFields.where((row) {
      if (filterType != 'All' && row.messageType != filterType) {
        return false;
      }
      if (searchText.isNotEmpty &&
          !row.name.toLowerCase().contains(searchText)) {
        return false;
      }
      return true;
    }).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _serialService?.dispose();
    super.dispose();
  }
}
