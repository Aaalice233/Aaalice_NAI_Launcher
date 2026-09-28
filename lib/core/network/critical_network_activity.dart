import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

enum CriticalNetworkActivityType {
  imageGeneration,
  vibeEncoding,
  directorTool,
  cloudUpscale,
}

/// Process-local authority for latency-sensitive, potentially billed network
/// work. Leases are acquired at the API boundary so early returns before a
/// request do not create false activity and every transport exit releases it.
class CriticalNetworkActivityCoordinator extends ChangeNotifier {
  CriticalNetworkActivityCoordinator();

  static final instance = CriticalNetworkActivityCoordinator();

  final Map<CriticalNetworkActivityType, int> _counts = {};
  int _activeLeaseCount = 0;

  bool get isActive => _activeLeaseCount > 0;
  int get activeLeaseCount => _activeLeaseCount;
  Set<CriticalNetworkActivityType> get activeTypes => Set.unmodifiable(
    _counts.entries.where((entry) => entry.value > 0).map((entry) => entry.key),
  );

  CriticalNetworkActivityLease acquire(CriticalNetworkActivityType type) {
    final wasActive = isActive;
    _activeLeaseCount++;
    _counts[type] = (_counts[type] ?? 0) + 1;
    if (!wasActive) notifyListeners();
    AppLogger.d(
      'Critical network activity begin: type=${type.name}, '
          'active=$_activeLeaseCount',
      'NetworkQoS',
    );
    return CriticalNetworkActivityLease._(this, type, DateTime.now());
  }

  void _release(CriticalNetworkActivityType type, DateTime startedAt) {
    final count = _counts[type] ?? 0;
    if (count <= 0 || _activeLeaseCount <= 0) {
      throw StateError('Unbalanced critical network activity lease: $type');
    }
    if (count == 1) {
      _counts.remove(type);
    } else {
      _counts[type] = count - 1;
    }
    _activeLeaseCount--;
    AppLogger.d(
      'Critical network activity end: type=${type.name}, '
          'active=$_activeLeaseCount, elapsedMs='
          '${DateTime.now().difference(startedAt).inMilliseconds}',
      'NetworkQoS',
    );
    if (!isActive) notifyListeners();
  }
}

class CriticalNetworkActivityLease {
  CriticalNetworkActivityLease._(this._owner, this.type, this._startedAt);

  final CriticalNetworkActivityCoordinator _owner;
  final CriticalNetworkActivityType type;
  final DateTime _startedAt;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _owner._release(type, _startedAt);
  }
}
