import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/incoming_image_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/image_share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'reads startup share and empty queue through the platform channel',
    () async {
      var takes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'takeNext');
        return takes++ == 0 ? {'text': 'https://example.com/image.png'} : null;
      });
      final service = IncomingImageShareService(channel: channel)..start();
      addTearDown(() {
        service.dispose();
        messenger.setMockMethodCallHandler(channel, null);
      });
      expect(await service.takeNext(), {
        'text': 'https://example.com/image.png',
      });
      expect(await service.takeNext(), isNull);
    },
  );

  test(
    'warm notification wakes consumers and shutdown closes stream',
    () async {
      final service = IncomingImageShareService(channel: channel)..start();
      final received = Completer<void>();
      final closed = Completer<void>();
      final subscription = service.available.listen(
        (_) => received.complete(),
        onDone: () => closed.complete(),
      );
      final response = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('available'),
        ),
        (_) => response.complete(),
      );
      await response.future;
      await received.future;
      service.dispose();
      await closed.future;
      await subscription.cancel();
    },
  );

  test('native read errors preserve platform code', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'image_share_read_failed',
        message: 'Permission denied',
      );
    });
    final service = IncomingImageShareService(channel: channel)..start();
    addTearDown(() {
      service.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });
    await expectLater(
      service.takeNext(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'image_share_read_failed',
        ),
      ),
    );
  });
}
