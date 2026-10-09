import 'dart:async';

/// 자동 전송 설정
///
/// 메시지별 자동 전송 주기를 관리합니다.
class AutoSendConfig {
  /// 메시지 ID
  final int messageId;

  /// 메시지 이름
  final String messageName;

  /// 활성화 여부
  bool enabled;

  /// 전송 주기 (밀리초)
  int intervalMs;

  /// 내부 타이머
  Timer? _timer;

  /// 전송 콜백
  void Function()? _onTick;

  /// 마지막 전송 시간
  DateTime? lastSentTime;

  /// 전송 횟수
  int sendCount = 0;

  /// 기본 전송 주기 (밀리초)
  static const int defaultIntervalMs = 500;

  /// 최소 전송 주기 (밀리초)
  static const int minIntervalMs = 10;

  /// 최대 전송 주기 (밀리초)
  static const int maxIntervalMs = 60000;

  AutoSendConfig({
    required this.messageId,
    required this.messageName,
    this.enabled = false,
    this.intervalMs = defaultIntervalMs,
  });

  /// 자동 전송을 시작합니다.
  void start(void Function() onTick) {
    stop();
    _onTick = onTick;

    if (enabled && intervalMs >= minIntervalMs) {
      _timer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) {
          lastSentTime = DateTime.now();
          sendCount++;
          _onTick?.call();
        },
      );
    }
  }

  /// 자동 전송을 중지합니다.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 활성화 상태를 토글합니다.
  void toggle(void Function() onTick) {
    enabled = !enabled;
    if (enabled) {
      start(onTick);
    } else {
      stop();
    }
  }

  /// 전송 주기를 설정합니다.
  ///
  /// 주기는 [minIntervalMs]와 [maxIntervalMs] 범위로 제한됩니다.
  void setInterval(int ms) {
    intervalMs = ms.clamp(minIntervalMs, maxIntervalMs);

    // 이미 실행 중이면 타이머 재시작
    if (_timer != null && _onTick != null) {
      start(_onTick!);
    }
  }

  /// 타이머가 실행 중인지 확인
  bool get isRunning => _timer != null && _timer!.isActive;

  /// 전송 횟수 초기화
  void resetCount() {
    sendCount = 0;
  }

  /// 리소스 해제
  void dispose() {
    stop();
    _onTick = null;
  }

  @override
  String toString() =>
      'AutoSendConfig(msg: $messageName, enabled: $enabled, interval: ${intervalMs}ms)';
}

/// 자동 전송 관리자
///
/// 여러 메시지의 자동 전송을 관리합니다.
class AutoSendManager {
  /// 자동 전송 설정 맵 (메시지 ID → 설정)
  final Map<int, AutoSendConfig> configs = {};

  /// 전송 콜백 (메시지 ID를 인자로 받음)
  final void Function(int messageId) onSendMessage;

  AutoSendManager({required this.onSendMessage});

  /// 설정 추가
  void addConfig(AutoSendConfig config) {
    configs[config.messageId] = config;
  }

  /// 설정 가져오기
  AutoSendConfig? getConfig(int messageId) => configs[messageId];

  /// 자동 전송 토글
  void toggle(int messageId) {
    final config = configs[messageId];
    if (config != null) {
      config.toggle(() => onSendMessage(messageId));
    }
  }

  /// 자동 전송 활성화
  void enable(int messageId) {
    final config = configs[messageId];
    if (config != null && !config.enabled) {
      config.enabled = true;
      config.start(() => onSendMessage(messageId));
    }
  }

  /// 자동 전송 비활성화
  void disable(int messageId) {
    final config = configs[messageId];
    if (config != null && config.enabled) {
      config.enabled = false;
      config.stop();
    }
  }

  /// 전송 주기 설정
  void setInterval(int messageId, int intervalMs) {
    final config = configs[messageId];
    if (config != null) {
      config.setInterval(intervalMs);
    }
  }

  /// 모든 자동 전송 중지
  void stopAll() {
    for (final config in configs.values) {
      config.stop();
    }
  }

  /// 모든 활성화된 설정 시작
  void startAll() {
    for (final config in configs.values) {
      if (config.enabled) {
        config.start(() => onSendMessage(config.messageId));
      }
    }
  }

  /// 활성화된 설정 목록
  List<AutoSendConfig> get enabledConfigs =>
      configs.values.where((c) => c.enabled).toList();

  /// 모든 설정 목록
  List<AutoSendConfig> get allConfigs => configs.values.toList();

  /// 리소스 해제
  void dispose() {
    for (final config in configs.values) {
      config.dispose();
    }
    configs.clear();
  }
}
