import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

      final baked = await LayerPatchBaker.replaceRegion(
        layer,
        patch: patch,
        patchRect: const Rect.fromLTWH(6, 6, 4, 4),
      );
      addTearDown(baked.dispose);

      expect(baked.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      layers.replaceLayerBaseImageSync(
        layer.id,
        baked.image.clone(),
        baked.bytes,
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

      final baked = await LayerPatchBaker.eraseRegion(
        layer,
        region: Path()..addRect(const Rect.fromLTWH(0, 0, 2, 2)),
      );
      addTearDown(baked.dispose);
      layers.replaceLayerBaseImageSync(
        layer.id,
        baked.image.clone(),
        baked.bytes,
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

      final moved = await LayerPatchBaker.moveRegion(
        layer,
        region: Path()..addRect(const Rect.fromLTWH(4, 0, 4, 4)),
        offset: const Offset(6, 0),
        extentLock: lock,
      );
      addTearDown(moved.dispose);
      expect(moved.bounds, lock);

      final unlocked = await LayerPatchBaker.moveRegion(
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
        await LayerPatchBaker.extractRegion(
          layer,
          region: Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)),
        ),
        isNull,
      );
      expect(
        await LayerPatchBaker.cropTo(layer, const Rect.fromLTWH(0, 0, 4, 4)),
        isNull,
      );

      final cropped = await LayerPatchBaker.cropTo(
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

      final merged = await LayerPatchBaker.mergeDown(
        upper: upper,
        lower: lower,
      );
      addTearDown(merged.dispose);
      layers.replaceLayerBaseImageSync(
        lower.id,
        merged.image.clone(),
        merged.bytes,
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
}

LayerManager _layers() {
  final layers = LayerManager();
  addTearDown(layers.dispose);
  return layers;
}
