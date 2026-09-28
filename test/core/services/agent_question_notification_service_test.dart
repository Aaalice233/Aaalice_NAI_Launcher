import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/agent_question_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/agent-questions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AgentQuestionNotificationService service;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    service = AgentQuestionNotificationService(
      supported: true,
      channel: channel,
      permissionGranted: () async => true,
    );
  });
  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> show() => service.show(
    requestId: 'question-1',
    title: '等待回答',
    message: '请打开对话',
    expiresAt: DateTime.now().add(const Duration(minutes: 2)),
  );

  test(
    'show carries deadline and cancellation follows a pending platform show',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'show') {
          started.complete();
          await finish.future;
        }
        return null;
      });
      final showing = show();
      await started.future;
      final cancelling = service.cancel();
      expect(calls.map((call) => call.method), ['show']);
      expect((calls.first.arguments as Map)['requestId'], 'question-1');
      expect((calls.first.arguments as Map)['expiresAt'], isA<int>());
      finish.complete();
      await showing;
      await cancelling;
      expect(calls.map((call) => call.method), ['show', 'cancel']);
    },
  );

  test('permission denial is explicit and does not prevent cleanup', () async {
    service.dispose();
    service = AgentQuestionNotificationService(
      supported: true,
      channel: channel,
      permissionGranted: () async => false,
    );
    await expectLater(show(), throwsStateError);
    await service.cancel();
    expect(calls.map((call) => call.method), ['cancel']);
  });

  test(
    'notification tap delivers the exact request and expired requests are not posted',
    () async {
      final opened = service.opened.first;
      final replied = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('open', 'question-1'),
        ),
        (_) => replied.complete(),
      );
      expect(await opened, 'question-1');
      await replied.future;
      await service.show(
        requestId: 'old',
        title: 'old',
        message: 'old',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(calls, isEmpty);
    },
  );
}
