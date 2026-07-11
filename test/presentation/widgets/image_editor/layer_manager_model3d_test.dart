import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/model3d_layer_data.dart';

/// 1x1 透明 PNG
final _png1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// 1x1 红色 PNG
final _png2 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('replaceLayerBaseImage swaps bitmap and keeps model3d', () async {
    final manager = LayerManager();
    addTearDown(manager.dispose);

    final layer = await manager.addLayerFromImage(_png1, name: '3D Layer');
    expect(layer, isNotNull);
    layer!.model3d = const Model3dLayerData(
      modelRef: 'builtin:mannequin',
      sceneState: {'version': 1},
    );
    final before = layer.baseImageBytes;

    final replaced = await manager.replaceLayerBaseImage(layer.id, _png2);
    expect(replaced, same(layer));
    expect(layer.baseImageBytes, isNot(equals(before)));
    expect(layer.model3d?.modelRef, 'builtin:mannequin');
  });

  test('replaceLayerBaseImage returns null for unknown id', () async {
    final manager = LayerManager();
    addTearDown(manager.dispose);
    expect(await manager.replaceLayerBaseImage('nope', _png1), isNull);
  });

  test('clone() copies model3d metadata', () async {
    final manager = LayerManager();
    addTearDown(manager.dispose);

    final layer = await manager.addLayerFromImage(_png1, name: '3D Layer');
    expect(layer, isNotNull);
    layer!.model3d = const Model3dLayerData(
      modelRef: 'builtin:mannequin',
      sceneState: {'version': 1},
    );

    final cloned = layer.clone();
    addTearDown(cloned.dispose);

    expect(cloned.model3d?.modelRef, 'builtin:mannequin');
  });

  test('cloneAsync() copies model3d metadata', () async {
    final manager = LayerManager();
    addTearDown(manager.dispose);

    final layer = await manager.addLayerFromImage(_png1, name: '3D Layer');
    expect(layer, isNotNull);
    layer!.model3d = const Model3dLayerData(
      modelRef: 'builtin:mannequin',
      sceneState: {'version': 1},
    );

    final cloned = await layer.cloneAsync();
    addTearDown(cloned.dispose);

    expect(cloned.model3d?.modelRef, 'builtin:mannequin');
    // cloneAsync 会重新解码底图,顺带确认底图也完整复制
    expect(cloned.hasBaseImage, isTrue);
  });
}
