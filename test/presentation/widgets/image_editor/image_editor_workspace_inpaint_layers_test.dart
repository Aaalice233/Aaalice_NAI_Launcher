import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'image_editor_workspace_harness.dart';
import 'layers/layer_pixel_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('inpaint sessions turn the drawing layer into a mask', (
    tester,
  ) async {
    final (key, session) = await _pumpInpaintWorkspace(tester);
    final state = session.editorState;

    expect(key.currentState!.debugLayerNames, ['Mask']);
    expect(state.layerManager.layers.single.isMask, isTrue);
    expect(state.rolePolicy.rolesEnabled, isTrue);
  });

  testWidgets('pixel-only tools give way to the brush on mask layers', (
    tester,
  ) async {
    final (key, session) = await _pumpInpaintWorkspace(tester);
    final state = session.editorState;
    final workspace = key.currentState!;
    final mask = state.layerManager.activeLayer!;
    // 模糊收在编辑组的修饰族折叠按钮里，没有单独的提示可找
    final blurButton = find.byKey(const ValueKey('editor-tool-edit:blur'));
    expect(blurButton, findsNothing);

    state.layerCommands.addLayer(name: 'Image');
    await tester.pumpAndSettle();
    expect(blurButton, findsOneWidget);
    workspace.debugSetToolById('blur');
    await tester.pumpAndSettle();
    expect(workspace.debugCurrentToolId, 'blur');

    state.layerManager.setActiveLayer(mask.id);
    await tester.pumpAndSettle();

    expect(workspace.debugCurrentToolId, 'brush');
    // 模糊仍留在编辑组，再点它会切回图片层
    expect(blurButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closed region fill writes into the outline layer even when it crosses the frame',
    (tester) async {
      final (_, session) = await _pumpInpaintWorkspace(tester);
      final state = session.editorState;
      final mask = state.layerManager.activeLayer!;
      StrokeData outline(List<Offset> points) => StrokeData(
        points: points,
        size: 8,
        color: const Color(0xFFFFFFFF),
        opacity: 1,
        hardness: 1,
      );
      state.historyManager.execute(
        AddStrokeAction(
          layerId: mask.id,
          stroke: outline(const [
            Offset(100, 100),
            Offset(300, 100),
            Offset(300, 300),
            Offset(100, 300),
            Offset(100, 100),
          ]),
        ),
        state,
      );
      // 伸出取景框的一笔：旧实现会因此保留原层，再叠一个同名蒙版层
      state.historyManager.execute(
        AddStrokeAction(
          layerId: mask.id,
          stroke: outline(const [Offset(-40, 200), Offset(-10, 200)]),
        ),
        state,
      );
      const probe = Rect.fromLTRB(-50, 90, 310, 310);

      await tester.runAsync(
        () => state.fillClosedRegionAt(const Offset(200, 200)),
      );
      await tester.pump();

      expect(state.layerManager.maskLayers.toList(), [mask]);
      final filled = (await tester.runAsync(
        () => LayerPixels.of(mask, probe),
      ))!;
      expect(filled.alphaAt(200, 200), greaterThan(0));
      expect(filled.alphaAt(-25, 200), greaterThan(0));

      expect(state.undo(), isTrue);
      expect(state.layerManager.maskLayers.toList(), [mask]);
      expect(mask.strokes, hasLength(2));
      final restored = (await tester.runAsync(
        () => LayerPixels.of(mask, probe),
      ))!;
      expect(restored.alphaAt(200, 200), 0);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('dropped images become image layers under the masks', (
    tester,
  ) async {
    final (key, session) = await _pumpInpaintWorkspace(tester);
    final state = session.editorState;
    final mask = state.layerManager.activeLayer!;

    await tester.runAsync(() async {
      final png = await solidPng(64, 64, const Color(0xFF00FF00));
      await key.currentState!.debugImportDroppedImageLayer('photo.png', png);
    });
    await settleLayerThumbnails(tester);

    final layers = state.layerManager.layers;
    expect(layers, hasLength(2));
    expect(layers.first, same(mask));
    expect(layers.last.isMask, isFalse);
    // 小图按原尺寸放在取景框中央，带着变换框等待摆放
    expect(layers.last.contentBounds, const Rect.fromLTWH(224, 224, 64, 64));
    expect(state.layerTransformer.isActive, isTrue);
    expect(state.layerManager.activeLayer, same(layers.last));
    expect(state.rolePolicy.isValidOrder(layers), isTrue);
  });
}

Future<(GlobalKey<ImageEditorWorkspaceState>, ImageEditorController)>
_pumpInpaintWorkspace(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.reset);

  final config = ImageEditorSessionConfig(
    initialSize: const Size(512, 512),
    mode: ImageEditorMode.inpaint,
    debugOptions: const ImageEditorDebugOptions(disableDropRegion: true),
  );
  final session = ImageEditorController(config: config);
  addTearDown(session.dispose);
  final key = GlobalKey<ImageEditorWorkspaceState>();

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: InteractionPolicyScope(
        initialPolicy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
        child: ImageEditorWorkspace(
          key: key,
          controller: session,
          config: config,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (key, session);
}
