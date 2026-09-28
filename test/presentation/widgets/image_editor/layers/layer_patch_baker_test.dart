import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_patch_baker.dart';

import 'layer_pixel_test_helpers.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('replaceRegion keeps pixels outside the patch and grows to it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(layers, layer, size: const Size(8, 8), color: _red);
      final patch = await solidImage(4, 4, _blue);
      addTearDown(patch.dispose);

      final baked = LayerPatchBaker.replaceRegion(
        layer,
        patch: patch,
        patchRect: const Rect.fromLTWH(6, 6, 4, 4),
      );
      addTearDown(baked.dispose);

      expect(baked.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      layers.replaceLayerBaseRasterSync(
        layer.id,
        baked.raster.retain(),
        offset: baked.offset,
      );
      final pixels = await LayerPixels.of(layer, baked.bounds);
      expect(pixels.at(1, 1), [255, 0, 0, 255]);
      expect(pixels.at(7, 7), [0, 0, 255, 255]);
      expect(pixels.at(9, 9), [0, 0, 255, 255]);
    });
  });

  testWidgets('baking ignores the layer opacity so it is not applied twice', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(layers, layer, size: const Size(8, 8), color: _red);
      layer.opacity = 0.3;

      final baked = LayerPatchBaker.eraseRegion(
        layer,
        region: Path()..addRect(const Rect.fromLTWH(0, 0, 2, 2)),
      );
      addTearDown(baked.dispose);
      layers.replaceLayerBaseRasterSync(
        layer.id,
        baked.raster.retain(),
        offset: baked.offset,
      );

      final pixels = await LayerPixels.of(
        layer,
        const Rect.fromLTWH(0, 0, 8, 8),
      );
      expect(pixels.alphaAt(1, 1), 0);
      expect(pixels.at(5, 5), [255, 0, 0, 255]);
    });
  });

  testWidgets('an extent lock pins the output rect', (tester) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(layers, layer, size: const Size(8, 8), color: _red);
      const lock = Rect.fromLTWH(0, 0, 8, 8);

      final moved = LayerPatchBaker.moveRegion(
        layer,
        region: Path()..addRect(const Rect.fromLTWH(4, 0, 4, 4)),
        offset: const Offset(6, 0),
        extentLock: lock,
      );
      addTearDown(moved.dispose);
      expect(moved.bounds, lock);

      final unlocked = LayerPatchBaker.moveRegion(
        layer,
        region: Path()..addRect(const Rect.fromLTWH(4, 0, 4, 4)),
        offset: const Offset(6, 0),
      );
      addTearDown(unlocked.dispose);
      expect(unlocked.bounds, const Rect.fromLTWH(0, 0, 14, 8));
    });
  });

  testWidgets('extractRegion and cropTo return null without overlap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(
        layers,
        layer,
        size: const Size(8, 8),
        color: _red,
        offset: const Offset(10, 10),
      );

      expect(
        LayerPatchBaker.extractRegion(
          layer,
          region: Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)),
        ),
        isNull,
      );
      expect(
        LayerPatchBaker.cropTo(layer, const Rect.fromLTWH(0, 0, 4, 4)),
        isNull,
      );

      final cropped = LayerPatchBaker.cropTo(
        layer,
        const Rect.fromLTWH(12, 12, 20, 20),
      );
      addTearDown(() => cropped?.dispose());
      expect(cropped!.bounds, const Rect.fromLTWH(12, 12, 6, 6));
    });
  });

  testWidgets('mergeDown applies the upper layer blend exactly once', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final lower = layers.addLayer(name: 'lower');
      final upper = layers.addLayer(name: 'upper', index: 0);
      await fillLayer(layers, lower, size: const Size(4, 4), color: _red);
      await fillLayer(layers, upper, size: const Size(4, 4), color: _blue);
      upper.opacity = 0.5;
      lower.opacity = 0.2;

      final merged = LayerPatchBaker.mergeDown(upper: upper, lower: lower);
      addTearDown(merged.dispose);
      layers.replaceLayerBaseRasterSync(
        lower.id,
        merged.raster.retain(),
        offset: merged.offset,
      );

      // 下层自身的不透明度留在图层属性上，不烘焙进像素
      final pixels = await LayerPixels.of(
        lower,
        const Rect.fromLTWH(0, 0, 4, 4),
      );
      final pixel = pixels.at(2, 2);
      expect(pixel[0], closeTo(127, 2));
      expect(pixel[2], closeTo(128, 2));
      expect(pixel[3], 255);
    });
  });

  testWidgets('paintOver only changes pixels inside the dirty rect', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(layers, layer, size: const Size(8, 8), color: _red);

      final baked = LayerPatchBaker.paintOver(
        layer,
        dirtyRect: const Rect.fromLTWH(6, 6, 4, 4),
        paint: (canvas) => canvas.drawRect(
          const Rect.fromLTWH(0, 0, 20, 20),
          Paint()..color = _blue,
        ),
      );
      expect(baked.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      layers.replaceLayerBaseRasterSync(
        layer.id,
        baked.raster,
        offset: baked.offset,
      );

      final pixels = await LayerPixels.of(layer, baked.bounds);
      expect(pixels.at(1, 1), [255, 0, 0, 255]);
      expect(pixels.at(7, 7), [0, 0, 255, 255]);
      expect(pixels.alphaAt(8, 1), 0, reason: 'outside the dirty rect');
    });
  });

  testWidgets(
    'a baked raster detaches from its sources without changing pixels',
    (tester) async {
      await tester.runAsync(() async {
        final layers = _layers();
        final layer = layers.addLayer(name: 'layer');
        await fillLayer(layers, layer, size: const Size(8, 8), color: _red);
        final baked = LayerPatchBaker.eraseRegion(
          layer,
          region: Path()..addRect(const Rect.fromLTWH(0, 0, 4, 8)),
        );
        final raster = baked.raster;
        final rendered = raster.image;
        layers.replaceLayerBaseRasterSync(
          layer.id,
          raster,
          offset: baked.offset,
        );

        await raster.detached.timeout(const Duration(seconds: 5));

        expect(identical(raster.image, rendered), isFalse);
        final pixels = await LayerPixels.of(layer, baked.bounds);
        expect(pixels.alphaAt(1, 1), 0);
        expect(pixels.at(6, 6), [255, 0, 0, 255]);
      });
    },
  );

  testWidgets('releasing a raster before it detaches is safe', (tester) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(layers, layer, size: const Size(8, 8), color: _red);
      final baked = LayerPatchBaker.cropTo(
        layer,
        const Rect.fromLTWH(0, 0, 4, 4),
      )!;

      baked.dispose();

      await baked.raster.detached.timeout(const Duration(seconds: 5));
    });
  });

  testWidgets('png bytes are encoded on demand and cached', (tester) async {
    await tester.runAsync(() async {
      final layers = _layers();
      final layer = layers.addLayer(name: 'layer');
      await fillLayer(layers, layer, size: const Size(8, 8), color: _red);
      final baked = LayerPatchBaker.cropTo(
        layer,
        const Rect.fromLTWH(0, 0, 4, 2),
      )!;
      addTearDown(baked.dispose);
      expect(baked.bytes, isNull);

      final bytes = await baked.raster.encodePng().timeout(
        const Duration(seconds: 5),
      );

      expect(baked.bytes, same(bytes));
      final decoded = img.decodePng(bytes!)!;
      expect((decoded.width, decoded.height), (4, 2));
      final pixel = decoded.getPixel(1, 1);
      expect((pixel.r, pixel.g, pixel.b, pixel.a), (255, 0, 0, 255));
    });
  });
}

LayerManager _layers() {
  final layers = LayerManager();
  addTearDown(layers.dispose);
  return layers;
}
