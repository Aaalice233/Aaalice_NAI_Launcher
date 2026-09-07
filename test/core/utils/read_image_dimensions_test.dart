import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/read_image_dimensions.dart';

class _Descriptor extends Fake implements ui.ImageDescriptor {
  bool disposed = false;
  @override
  int get width => 32;
  @override
  int get height => 48;
  @override
  void dispose() => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dimension read releases descriptor and buffer on success', () async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(Uint8List(4));
    addTearDown(() {
      if (!buffer.debugDisposed) buffer.dispose();
    });
    final descriptor = _Descriptor();
    final result = await readImageDimensions(
      'synthetic',
      createBuffer: (_) async => buffer,
      createDescriptor: (_) async => descriptor,
    );
    expect(result, const ui.Size(32, 48));
    expect(descriptor.disposed, isTrue);
    expect(buffer.debugDisposed, isTrue);
  });

  test('dimension read releases buffer if descriptor creation fails', () async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(Uint8List(4));
    addTearDown(() {
      if (!buffer.debugDisposed) buffer.dispose();
    });
    await expectLater(
      readImageDimensions(
        'synthetic',
        createBuffer: (_) async => buffer,
        createDescriptor: (_) async =>
            throw StateError('synthetic decode failure'),
      ),
      throwsStateError,
    );
    expect(buffer.debugDisposed, isTrue);
  });

  test(
    'real encoded dimensions are preserved without decoding a frame',
    () async {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        Uint8List.fromList(img.encodePng(img.Image(width: 17, height: 29))),
      );
      addTearDown(() {
        if (!buffer.debugDisposed) buffer.dispose();
      });
      final result = await readImageDimensions(
        'synthetic',
        createBuffer: (_) async => buffer,
      );
      expect(result, const ui.Size(17, 29));
      expect(buffer.debugDisposed, isTrue);
    },
  );
}
