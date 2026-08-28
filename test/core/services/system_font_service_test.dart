import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/system_font_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.nailauncher/system_fonts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Windows invokes the native font enumeration contract', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getSystemFonts');
      return ['Segoe UI', 'Arial'];
    });
    final service = SystemFontService(
      channel: channel,
      capabilities: PlatformCapabilities.forPlatform(TargetPlatform.windows),
    );

    await expectLater(
      service.getSystemFonts(),
      completion(['Segoe UI', 'Arial']),
    );
  });

  test('unsupported platforms reject without invoking the channel', () async {
    var invocationCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invocationCount++;
      return ['Should not be returned'];
    });
    final service = SystemFontService(
      channel: channel,
      capabilities: PlatformCapabilities.forPlatform(TargetPlatform.android),
    );

    await expectLater(
      service.getSystemFonts(),
      throwsA(isA<UnsupportedError>()),
    );
    expect(invocationCount, 0);
  });

  test('Windows native bridge failures remain observable', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'enumeration_failed', message: 'failed');
    });
    final service = SystemFontService(
      channel: channel,
      capabilities: PlatformCapabilities.forPlatform(TargetPlatform.windows),
    );

    await expectLater(
      service.getSystemFonts(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'enumeration_failed',
        ),
      ),
    );
  });
}
