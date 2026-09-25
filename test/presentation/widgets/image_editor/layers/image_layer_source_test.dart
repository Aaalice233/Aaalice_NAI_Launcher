import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/image_layer_source.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';

import 'layer_pixel_test_helpers.dart';

const _red = Color(0xFFFF0000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports no change before a baseline is captured', () {
    final session = _session();
    session.base.addStroke(_stroke());

    expect(session.source.hasChanges, isFalse);
  });

  test('only image layer edits count as source changes', () {
    final session = _session();
    session.source.captureBaseline();

    session.mask.addStroke(_stroke());
    session.mask.opacity = 0.2;
    expect(session.source.hasChanges, isFalse);

    session.base.addStroke(_stroke());
    expect(session.source.hasChanges, isTrue);
  });

  test('visibility, opacity and new image layers are source changes', () {
    final session = _session();
    final layers = session.layers;

    session.source.captureBaseline();
    session.base.visible = false;
    expect(session.source.hasChanges, isTrue);

    session.base.visible = true;
    expect(session.source.hasChanges, isFalse);
    session.base.opacity = 0.5;
    expect(session.source.hasChanges, isTrue);

    session.base.opacity = 1;
    layers.addLayer(name: 'added', index: 1);
    expect(session.source.hasChanges, isTrue);
  });

  testWidgets('the composite leaves masks out and keeps empty areas clear', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final session = _session();
      await fillLayer(
        session.layers,
        session.base,
        size: const Size(8, 8),
        color: _red,
      );
      session.mask.addStroke(_stroke());

      final png = await session.source.renderComposite(
        const Rect.fromLTWH(0, 0, 16, 16),
      );
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      final rgba = data!.buffer.asUint8List();
      List<int> at(int x, int y) {
        final i = (y * 16 + x) * 4;
        return rgba.sublist(i, i + 4);
      }

      expect(at(2, 2), [255, 0, 0, 255]);
      expect(at(12, 12)[3], 0);
    });
  });
}

({LayerManager layers, Layer base, Layer mask, ImageLayerSource source})
_session() {
  final layers = LayerManager();
  addTearDown(layers.dispose);
  final base = layers.addLayer(name: 'base');
  final mask = layers.addLayer(name: 'mask', index: 0, role: LayerRole.mask);
  return (
    layers: layers,
    base: base,
    mask: mask,
    source: ImageLayerSource(layers),
  );
}

StrokeData _stroke() {
  return StrokeData(
    points: const [Offset(10, 10), Offset(14, 14)],
    size: 4,
    color: const Color(0xFF60AAFF),
    opacity: 1,
    hardness: 1,
  );
}
