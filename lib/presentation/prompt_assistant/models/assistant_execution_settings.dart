enum AssistantConcurrencyMode { automatic, manual }

/// Persisted policy only. Learned limits and pending requests are device-local.
class AssistantConcurrencySettings {
  const AssistantConcurrencySettings({
    this.mode = AssistantConcurrencyMode.automatic,
    this.maxConcurrentRequests = 5,
  }) : assert(maxConcurrentRequests > 0);

  static const initialAutomaticConcurrency = 5;
  final AssistantConcurrencyMode mode;
  final int maxConcurrentRequests;

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'maxConcurrentRequests': maxConcurrentRequests,
  };

  factory AssistantConcurrencySettings.fromJson(Map<String, dynamic> json) {
    final count = json['maxConcurrentRequests'] ?? 5;
    if (count is! int || count < 1) {
      throw const FormatException(
        'Maximum concurrency must be a positive integer',
      );
    }
    return AssistantConcurrencySettings(
      mode: AssistantConcurrencyMode.values.firstWhere(
        (mode) => mode.name == json['mode'],
        orElse: () => AssistantConcurrencyMode.automatic,
      ),
      maxConcurrentRequests: count,
    );
  }
}

enum AssistantThinkingLevel {
  automatic,
  off,
  minimal,
  low,
  medium,
  high,
  xhigh,
  max,
}
