import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/model3d_layer_data.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/project/project_data.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/project/project_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 标准 1x1 透明 RGBA PNG(可被 Flutter 真实解码器解码;
/// image_share_sanitizer_test.dart 中的常量仅作字节级测试用,无法通过
/// ui.instantiateImageCodec 解码,故此处不复用)
const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    // EditorState 构造时 ToolManager 会异步读取 SharedPreferences;
    // runAsync 真实异步区中未 mock 会以未捕获错误形式挂掉测试
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('model3d_project_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('model3d layer round-trips through save/load/apply',
      (tester) async {
    await tester.runAsync(() async {
      final pngBytes = base64Decode(_oneByOnePngBase64);

      // 源状态:一个带位图的普通层 + 一个带位图与元数据的 3D 层
      final source = EditorState()..setCanvasSize(const Size(64, 64));
      addTearDown(source.dispose);

      final normalLayer = source.layerManager.addLayer(name: 'Normal');
      await normalLayer.setBaseImage(pngBytes);

      final model3dLayer = source.layerManager.addLayer(name: '3D');
      await model3dLayer.setBaseImage(pngBytes);
      model3dLayer.model3d = const Model3dLayerData(
        modelRef: 'builtin:mannequin',
        sceneState: {'version': 1},
      );

      // 保存 → 加载(公开 API 驱动 _createProjectData 的 gating 逻辑)
      final filePath = '${tempDir.path}/roundtrip.naiedit';
      await ProjectManager.saveProject(source, filePath);
      final project = await ProjectManager.loadProject(filePath);

      // 序列化侧断言:普通层不存底图(行为不变),3D 层存底图与元数据
      final normalData =
          project.layers.singleWhere((l) => l.id == normalLayer.id);
      expect(normalData.imageData, isNull);
      expect(normalData.model3d, isNull);

      final model3dData =
          project.layers.singleWhere((l) => l.id == model3dLayer.id);
      expect(model3dData.imageData, isNotNull);
      expect(model3dData.model3d, isNotNull);

      // 应用到全新状态(驱动 applyProjectData 的恢复分支)
      final restored = EditorState();
      addTearDown(restored.dispose);
      await ProjectManager.applyProjectData(restored, project);

      final restoredNormal = restored.layerManager.getLayerById(normalLayer.id);
      expect(restoredNormal, isNotNull);
      expect(restoredNormal!.model3d, isNull);
      expect(restoredNormal.baseImageBytes, isNull);

      final restored3d = restored.layerManager.getLayerById(model3dLayer.id);
      expect(restored3d, isNotNull);
      expect(restored3d!.baseImageBytes, isNotNull);
      expect(restored3d.baseImageBytes, pngBytes);
      // setBaseImage 成功解码才会置 baseImage(可解码性证明)
      expect(restored3d.hasBaseImage, isTrue);
      expect(restored3d.model3d?.modelRef, 'builtin:mannequin');
      expect(restored3d.model3d?.sceneState, {'version': 1});
    });
  });

  testWidgets('corrupted layer data degrades instead of failing load',
      (tester) async {
    await tester.runAsync(() async {
      // 一个正常图层 + 一个损坏图层(base64 非法、model3d 缺 modelRef):
      // 位图为主、3D 元数据为增强,单层数据损坏不应阻断整个项目加载。
      final project = ProjectData.fromJson({
        'version': 2,
        'width': 64,
        'height': 64,
        'layers': [
          {
            'id': 'normal1',
            'name': 'Normal',
            'visible': true,
            'locked': false,
            'opacity': 1.0,
            'blendMode': 'normal',
            'strokes': <dynamic>[],
          },
          {
            'id': 'corrupt1',
            'name': 'Corrupt 3D',
            'visible': true,
            'locked': false,
            'opacity': 1.0,
            'blendMode': 'normal',
            'strokes': <dynamic>[],
            'imageData': '!!!not-base64!!!',
            'model3d': {'bogus': true},
          },
        ],
        'foregroundColor': 0xFF000000,
        'backgroundColor': 0xFFFFFFFF,
      });

      final restored = EditorState();
      addTearDown(restored.dispose);

      // 不应抛出:损坏图层退化(缺位图/缺元数据),其余图层正常加载
      await ProjectManager.applyProjectData(restored, project);

      expect(restored.layerManager.getLayerById('normal1'), isNotNull);

      final corrupt = restored.layerManager.getLayerById('corrupt1');
      expect(corrupt, isNotNull);
      expect(corrupt!.model3d, isNull);
      expect(corrupt.hasBaseImage, isFalse);
    });
  });
}
