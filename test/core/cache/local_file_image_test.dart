import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_file_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nai_local_file_image_');
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await tempDir.delete(recursive: true);
  });

  String pathOf(String name) => '${tempDir.path}${Platform.pathSeparator}$name';

  test('同路径同长度内容被原地改写后生成新缓存键并解码出新像素', () async {
    final path = pathOf('overwritten.png');
    final red = _solidPng(img.ColorRgb8(255, 0, 0));
    final blue = _solidPng(img.ColorRgb8(0, 0, 255));
    expect(blue.length, red.length);

    await File(path).writeAsBytes(red, flush: true);
    File(path).setLastModifiedSync(DateTime(2026, 1, 1, 12));
    final provider = LocalFileImage(path);
    final redKey = await provider.obtainKey(ImageConfiguration.empty);
    expect(await _firstPixel(provider), (255, 0, 0));

    await File(path).writeAsBytes(blue, flush: true);
    File(path).setLastModifiedSync(DateTime(2026, 1, 1, 12, 0, 1));
    final blueKey = await provider.obtainKey(ImageConfiguration.empty);

    expect(blueKey, isNot(redKey));
    expect(blueKey.identity!.size, redKey.identity!.size);
    expect(await _firstPixel(provider), (0, 0, 255));
  });

  test('文件未变化时同步取得相等的键并在同一帧复用缓存条目', () async {
    final path = pathOf('stable.png');
    await File(path).writeAsBytes(_solidPng(img.ColorRgb8(0, 255, 0)));
    final first = LocalFileImage(path);
    final info = await _resolve(first);
    addTearDown(info.dispose);

    final key = await first.obtainKey(ImageConfiguration.empty);
    final sameFile = LocalFileImage(
      '${tempDir.path}${Platform.pathSeparator}.${Platform.pathSeparator}'
      'stable.png',
    );
    final keyFuture = sameFile.obtainKey(ImageConfiguration.empty);

    expect(keyFuture, isA<SynchronousFuture<LocalFileImageKey>>());
    expect(await keyFuture, key);
    expect(PaintingBinding.instance.imageCache.containsKey(key), isTrue);

    final firstStream = first.resolve(ImageConfiguration.empty);
    final secondStream = sameFile.resolve(ImageConfiguration.empty);
    expect(secondStream.completer, isNotNull);
    expect(secondStream.completer, same(firstStream.completer));
  });

  test('文件缺失时与 FileImage 报告同类错误且错误条目不会被复用', () async {
    final path = pathOf('missing.png');
    final provider = LocalFileImage(path);
    final missingKey = await provider.obtainKey(ImageConfiguration.empty);
    expect(missingKey.identity, isNull);

    final fileImageError = await _resolveError(FileImage(File(path)));
    final error = await _resolveError(provider);
    expect(error, isA<PathNotFoundException>());
    expect(error.runtimeType, fileImageError.runtimeType);
    await Future<void>.delayed(Duration.zero);
    expect(
      PaintingBinding.instance.imageCache.statusForKey(missingKey).untracked,
      isTrue,
    );

    await File(path).writeAsBytes(_solidPng(img.ColorRgb8(255, 0, 0)));
    expect(await _firstPixel(provider), (255, 0, 0));
  });

  test('空文件与 FileImage 一样报告无法解码', () async {
    final path = pathOf('empty.png');
    await File(path).writeAsBytes(const <int>[]);

    final error = await _resolveError(LocalFileImage(path));

    expect(error, isA<StateError>());
    expect('$error', contains('is empty and cannot be loaded as an image'));
  });

  test('解析键时文件缺失而加载前才出现时走错误路径且不留缓存', () async {
    final path = pathOf('appeared.png');
    final provider = LocalFileImage(path);
    final unknownKey = await provider.obtainKey(ImageConfiguration.empty);
    expect(unknownKey.identity, isNull);
    await File(path).writeAsBytes(_solidPng(img.ColorRgb8(255, 0, 0)));

    final completer = PaintingBinding.instance.imageCache.putIfAbsent(
      unknownKey,
      () => provider.loadImage(
        unknownKey,
        PaintingBinding.instance.instantiateImageCodecWithSize,
      ),
    )!;

    await expectLater(_firstImage(completer), throwsA(isA<StateError>()));
    expect(
      PaintingBinding.instance.imageCache.statusForKey(unknownKey).untracked,
      isTrue,
    );
    expect(await _firstPixel(provider), (255, 0, 0));
  });

  test('cacheWidth 与 cacheHeight 按 Image.file 的方式包装 ResizeImage', () async {
    final path = pathOf('resized.png');
    await File(
      path,
    ).writeAsBytes(img.encodePng(img.Image(width: 40, height: 20)));

    expect(LocalFileImage.withCacheSize(path), LocalFileImage(path));
    final provider = LocalFileImage.withCacheSize(
      path,
      cacheWidth: 10,
      scale: 2,
    );
    expect(provider, isA<ResizeImage>());
    final resized = provider as ResizeImage;
    expect(resized.width, 10);
    expect(resized.height, isNull);
    expect(resized.imageProvider, LocalFileImage(path, scale: 2));

    final info = await _resolve(provider);
    addTearDown(info.dispose);
    expect((info.image.width, info.image.height), (10, 5));
    expect(info.scale, 2);

    final before = await provider.obtainKey(ImageConfiguration.empty);
    File(path).setLastModifiedSync(DateTime(2026, 1, 2));
    expect(await provider.obtainKey(ImageConfiguration.empty), isNot(before));
  });

  test('provider 相等性与 FileImage 一样只看路径与 scale', () {
    final a = pathOf('a.png');
    final b = pathOf('b.png');

    expect(LocalFileImage(a), LocalFileImage(a));
    expect(LocalFileImage(a).hashCode, LocalFileImage(a).hashCode);
    expect(LocalFileImage(a), isNot(LocalFileImage(b)));
    expect(LocalFileImage(a), isNot(LocalFileImage(a, scale: 2)));
  });
}

Uint8List _solidPng(img.Color color) {
  final image = img.Image(width: 4, height: 4)..clear(color);
  // 不压缩时编码长度只取决于尺寸，才能构造“同长度不同内容”的改写
  return img.encodePng(image, level: 0);
}

Future<(int, int, int)> _firstPixel(ImageProvider provider) async {
  final info = await _resolve(provider);
  try {
    final pixels = await info.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    return (pixels!.getUint8(0), pixels.getUint8(1), pixels.getUint8(2));
  } finally {
    info.dispose();
  }
}

Future<ImageInfo> _resolve(ImageProvider provider) {
  final completer = Completer<ImageInfo>();
  late ImageStreamListener listener;
  final stream = provider.resolve(ImageConfiguration.empty);
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info);
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(const Duration(seconds: 5));
}

Future<Object> _resolveError(ImageProvider provider) async {
  try {
    final info = await _resolve(provider);
    info.dispose();
  } catch (error) {
    return error;
  }
  fail('$provider resolved an image instead of an error');
}

Future<ImageInfo> _firstImage(ImageStreamCompleter completer) {
  final result = Completer<ImageInfo>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      completer.removeListener(listener);
      if (!result.isCompleted) result.complete(info);
    },
    onError: (Object error, StackTrace? stackTrace) {
      completer.removeListener(listener);
      if (!result.isCompleted) result.completeError(error, stackTrace);
    },
  );
  completer.addListener(listener);
  return result.future.timeout(const Duration(seconds: 5));
}
