import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/system_gallery_publisher.dart';

void main() {
  final android = PlatformCapabilities.forPlatform(TargetPlatform.android);
  final windows = PlatformCapabilities.forPlatform(TargetPlatform.windows);
  final bytes = Uint8List.fromList(const [1, 2, 3]);

  late List<String> writes;

  SystemGalleryPublisher publisher({
    required bool syncEnabled,
    required PlatformCapabilities capabilities,
    Object? failWith,
  }) {
    return SystemGalleryPublisher(
      syncEnabled: syncEnabled,
      capabilities: capabilities,
      writeImage: (bytes, fileName, mimeType) async {
        if (failWith != null) throw failWith;
        writes.add('image:$fileName:$mimeType');
      },
      writeFile: (sourcePath, fileName, mimeType) async {
        if (failWith != null) throw failWith;
        writes.add('file:$sourcePath:$fileName:$mimeType');
      },
    );
  }

  setUp(() => writes = []);

  test('Android 开启同步时写入系统相册', () async {
    final subject = publisher(syncEnabled: true, capabilities: android);

    expect(subject.isActive, isTrue);
    expect(
      await subject.publishPng(bytes: bytes, fileName: 'a.png'),
      isA<SystemGalleryPublished>(),
    );
    expect(
      await subject.publishFile(
        sourcePath: '/gallery/b.png',
        fileName: 'b.png',
        mimeType: 'image/png',
      ),
      isA<SystemGalleryPublished>(),
    );
    expect(writes, [
      'image:a.png:image/png',
      'file:/gallery/b.png:b.png:image/png',
    ]);
  });

  test('Android 关闭同步时不触碰系统相册', () async {
    final subject = publisher(syncEnabled: false, capabilities: android);

    expect(subject.isActive, isFalse);
    expect(
      await subject.publishPng(bytes: bytes, fileName: 'a.png'),
      isA<SystemGallerySyncDisabled>(),
    );
    expect(
      await subject.publishFile(
        sourcePath: '/gallery/b.png',
        fileName: 'b.png',
      ),
      isA<SystemGallerySyncDisabled>(),
    );
    expect(writes, isEmpty);
  });

  test('不支持系统相册的平台忽略同步偏好', () async {
    final subject = publisher(syncEnabled: true, capabilities: windows);

    expect(subject.isActive, isFalse);
    expect(
      await subject.publishPng(bytes: bytes, fileName: 'a.png'),
      isA<SystemGalleryUnsupported>(),
    );
    expect(writes, isEmpty);
  });

  test('写入失败返回失败结果并可按原堆栈重新抛出', () async {
    final failure = StateError('denied');
    final subject = publisher(
      syncEnabled: true,
      capabilities: android,
      failWith: failure,
    );

    final outcome = await subject.publishPng(bytes: bytes, fileName: 'a.png');

    expect(
      outcome,
      isA<SystemGalleryPublishFailed>().having(
        (failed) => failed.error,
        'error',
        same(failure),
      ),
    );
    expect(outcome.throwIfFailed, throwsA(same(failure)));
  });

  test('成功与跳过结果调用 throwIfFailed 不抛出', () {
    expect(const SystemGalleryPublished().throwIfFailed, returnsNormally);
    expect(const SystemGallerySyncDisabled().throwIfFailed, returnsNormally);
    expect(const SystemGalleryUnsupported().throwIfFailed, returnsNormally);
  });
}
