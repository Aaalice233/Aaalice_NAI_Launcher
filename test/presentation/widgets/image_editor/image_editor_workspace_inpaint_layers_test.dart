import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final blurButton = find.byTooltip(RegExp(r'^Blur'));
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
    await _settleLayerThumbnails(tester);

    final layers = state.layerManager.layers;
    expect(layers, hasLength(2));
    expect(layers.first, same(mask));
    expect(layers.last.isMask, isFalse);
    expect(layers.last.contentBounds, state.frame);
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

/// 图层面板缩略图有 500ms 防抖，编码只在真实异步里完成；等到面板不再转圈
Future<void> _settleLayerThumbnails(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  final spinner = find.byType(CircularProgressIndicator);
  for (var i = 0; i < 10 && spinner.evaluate().isNotEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(spinner, findsNothing);
  await tester.pumpAndSettle();
}
