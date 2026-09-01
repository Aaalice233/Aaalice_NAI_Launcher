import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/async_work_pool.dart';

void main() {
  test('bounds active work and admits every queued task', () async {
    final pool = AsyncWorkPool(2);
    final release = Completer<void>();
    var active = 0;
    var maxActive = 0;
    var started = 0;

    Future<int?> run(int value) => pool.run(() async {
      started++;
      active++;
      maxActive = active > maxActive ? active : maxActive;
      await release.future;
      active--;
      return value;
    });

    final tasks = [run(1), run(2), run(3), run(4)];
    await Future<void>.delayed(Duration.zero);
    expect(started, 2);
    expect(maxActive, 2);

    release.complete();
    expect(await Future.wait(tasks), [1, 2, 3, 4]);
    expect(maxActive, 2);
  });

  test('drops a cancelled waiter without consuming a slot', () async {
    final pool = AsyncWorkPool(1);
    final release = Completer<void>();
    var cancelled = false;

    final first = pool.run(() async {
      await release.future;
      return 1;
    });
    final skipped = pool.run(() async => 2, isCancelled: () => cancelled);
    final last = pool.run(() async => 3);
    cancelled = true;
    release.complete();

    expect(await first, 1);
    expect(await skipped, isNull);
    expect(await last, 3);
  });
}
