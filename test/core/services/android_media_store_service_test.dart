import 'dart:io';

import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/android_media_store_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aaalice.nai_launcher/media_store');
  late Directory tempDir;

  setUp(() async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    tempDir = await Directory.systemTemp.createTemp('media_store_test_');
  });

  tearDown(() async {
    PlatformCapabilities.debugOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await tempDir.delete(recursive: true);
  });

  test('保存现有图片时传递真实路径、文件名和 MIME 到 Android MediaStore', () async {
    final source = File('${tempDir.path}/source.webp');
    await source.writeAsBytes(const [1, 2, 3, 4]);
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return 'content://media/external/images/media/42';
        });

    final uri = await AndroidMediaStoreService.saveImageFromPath(
      sourcePath: source.path,
      fileName: 'gallery image.webp',
    );

    expect(uri, 'content://media/external/images/media/42');
    expect(receivedCall?.method, 'saveImageFromPath');
    expect(receivedCall?.arguments, {
      'sourcePath': source.path,
      'fileName': 'gallery image.webp',
      'mimeType': 'image/webp',
    });
  });

  test('不存在的源文件不会调用 Android MediaStore', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          called = true;
          return null;
        });

    await expectLater(
      AndroidMediaStoreService.saveImageFromPath(
        sourcePath: '${tempDir.path}/missing.png',
        fileName: 'missing.png',
      ),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });
}
