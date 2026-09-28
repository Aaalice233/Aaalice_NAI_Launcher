import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/providers/font_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.nailauncher/system_fonts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'unsupported platforms omit the system font group and channel call',
    () async {
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.android,
      );
      var invocationCount = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        invocationCount++;
        return ['Should not be returned'];
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final groups = await container.read(allFontsProvider.future);

      expect(groups.keys, ['应用默认', 'Google Fonts']);
      expect(groups, isNot(contains('系统字体')));
      expect(invocationCount, 0);
    },
  );

  test('Windows exposes sorted system fonts', () async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => ['Segoe UI', 'Arial'],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final groups = await container.read(allFontsProvider.future);

    expect(groups['系统字体']?.map((font) => font.displayName), [
      'Arial',
      'Segoe UI',
    ]);
  });

  test('Windows bridge failures propagate through the font provider', () async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'enumeration_failed');
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(allFontsProvider.future),
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
