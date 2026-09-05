import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/android_foreground_task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/foreground');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  late AndroidForegroundTaskService service;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    service = AndroidForegroundTaskService(
      supported: true,
      channel: channel,
      requestNotificationPermission: () async {},
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'generation and Agent keep service until the last owner finishes',
    () async {
      final releases = await Future.wait([
        service.acquire(),
        service.acquire(),
      ]);
      expect(calls, ['start']);
      await releases.first();
      await releases.first();
      expect(calls, ['start']);
      await releases.last();
      expect(calls, ['start', 'stop']);
    },
  );

  test('new owner waits for pending stop before starting again', () async {
    final stop = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'stop') await stop.future;
      return null;
    });
    final release = await service.acquire();
    final stopping = release();
    final next = service.acquire();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['start', 'stop']);
    stop.complete();
    await stopping;
    final releaseNext = await next;
    expect(calls, ['start', 'stop', 'start']);
    await releaseNext();
  });

  test('failed start is reported and does not acquire an owner', () async {
    var failed = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (!failed) {
        failed = true;
        throw PlatformException(code: 'start_failed');
      }
      return null;
    });
    await expectLater(service.acquire(), throwsA(isA<PlatformException>()));
    final release = await service.acquire();
    await release();
    expect(calls, ['start', 'start', 'stop']);
  });

  test(
    'failed stop reaches the owner and a subsequent task can start',
    () async {
      var failed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'stop' && !failed) {
          failed = true;
          throw PlatformException(code: 'stop_failed');
        }
        return null;
      });
      final release = await service.acquire();
      await expectLater(release(), throwsA(isA<PlatformException>()));
      final next = await service.acquire();
      await next();
      expect(calls, ['start', 'stop', 'start', 'stop']);
    },
  );

  test(
    'unsupported platforms do not invoke permissions or native methods',
    () async {
      final service = AndroidForegroundTaskService(
        supported: false,
        channel: channel,
        requestNotificationPermission: () async =>
            fail('unexpected permission request'),
      );
      final release = await service.acquire();
      await release();
      expect(calls, isEmpty);
    },
  );
}
