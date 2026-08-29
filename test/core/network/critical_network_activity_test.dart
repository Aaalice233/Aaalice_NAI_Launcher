import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';

void main() {
  test('nested leases notify only on inactive-active boundaries', () {
    final coordinator = CriticalNetworkActivityCoordinator();
    expect(coordinator.isActive, isFalse);
    var notifications = 0;
    void listener() => notifications++;
    coordinator.addListener(listener);
    addTearDown(() => coordinator.removeListener(listener));

    final generation = coordinator.acquire(
      CriticalNetworkActivityType.imageGeneration,
    );
    final vibe = coordinator.acquire(CriticalNetworkActivityType.vibeEncoding);
    expect(coordinator.activeLeaseCount, 2);
    expect(notifications, 1);

    vibe.release();
    vibe.release();
    expect(coordinator.isActive, isTrue);
    expect(notifications, 1);

    generation.release();
    expect(coordinator.isActive, isFalse);
    expect(notifications, 2);
  });
}
