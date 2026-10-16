import 'dart:async';

/// Auto-send configuration
///
/// Manages auto-send intervals per message.
class AutoSendConfig {
  /// Message ID
  final int messageId;

  /// Message name
  final String messageName;

  /// Enabled state
  bool enabled;

  /// Send interval (milliseconds)
  int intervalMs;

  /// Internal timer
  Timer? _timer;

  /// Send callback
  void Function()? _onTick;

  /// Last send time
  DateTime? lastSentTime;

  /// Send count
  int sendCount = 0;

  /// Default send interval (milliseconds)
  static const int defaultIntervalMs = 500;

  /// Minimum send interval (milliseconds)
  static const int minIntervalMs = 10;

  /// Maximum send interval (milliseconds)
  static const int maxIntervalMs = 60000;

  AutoSendConfig({
    required this.messageId,
    required this.messageName,
    this.enabled = false,
    this.intervalMs = defaultIntervalMs,
  });

  /// Starts auto-send.
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

  /// Stops auto-send.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Toggles enabled state.
  void toggle(void Function() onTick) {
    enabled = !enabled;
    if (enabled) {
      start(onTick);
    } else {
      stop();
    }
  }

  /// Sets send interval.
  ///
  /// Interval is clamped to [minIntervalMs] and [maxIntervalMs] range.
  void setInterval(int ms) {
    intervalMs = ms.clamp(minIntervalMs, maxIntervalMs);

    // Restart timer if already running
    if (_timer != null && _onTick != null) {
      start(_onTick!);
    }
  }

  /// Checks if timer is running
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Resets send count
  void resetCount() {
    sendCount = 0;
  }

  /// Releases resources
  void dispose() {
    stop();
    _onTick = null;
  }

  @override
  String toString() =>
      'AutoSendConfig(msg: $messageName, enabled: $enabled, interval: ${intervalMs}ms)';
}

/// Auto-send manager
///
/// Manages auto-send for multiple messages.
class AutoSendManager {
  /// Auto-send config map (message ID → config)
  final Map<int, AutoSendConfig> configs = {};

  /// Send callback (receives message ID as argument)
  final void Function(int messageId) onSendMessage;

  AutoSendManager({required this.onSendMessage});

  /// Adds config
  void addConfig(AutoSendConfig config) {
    configs[config.messageId] = config;
  }

  /// Gets config
  AutoSendConfig? getConfig(int messageId) => configs[messageId];

  /// Toggles auto-send
  void toggle(int messageId) {
    final config = configs[messageId];
    if (config != null) {
      config.toggle(() => onSendMessage(messageId));
    }
  }

  /// Enables auto-send
  void enable(int messageId) {
    final config = configs[messageId];
    if (config != null && !config.enabled) {
      config.enabled = true;
      config.start(() => onSendMessage(messageId));
    }
  }

  /// Disables auto-send
  void disable(int messageId) {
    final config = configs[messageId];
    if (config != null && config.enabled) {
      config.enabled = false;
      config.stop();
    }
  }

  /// Sets send interval
  void setInterval(int messageId, int intervalMs) {
    final config = configs[messageId];
    if (config != null) {
      config.setInterval(intervalMs);
    }
  }

  /// Stops all auto-sends
  void stopAll() {
    for (final config in configs.values) {
      config.stop();
    }
  }

  /// Starts all enabled configs
  void startAll() {
    for (final config in configs.values) {
      if (config.enabled) {
        config.start(() => onSendMessage(config.messageId));
      }
    }
  }

  /// List of enabled configs
  List<AutoSendConfig> get enabledConfigs =>
      configs.values.where((c) => c.enabled).toList();

  /// List of all configs
  List<AutoSendConfig> get allConfigs => configs.values.toList();

  /// Releases resources
  void dispose() {
    for (final config in configs.values) {
      config.dispose();
    }
    configs.clear();
  }
}
