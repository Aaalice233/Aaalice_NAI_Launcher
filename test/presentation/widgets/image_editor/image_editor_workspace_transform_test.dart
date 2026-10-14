import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/move_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/move_tool_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'image_editor_workspace_harness.dart';
import 'layers/layer_pixel_test_helpers.dart';

const _touchPolicy = InteractionPolicy(
  modality: InteractionModality.touch,
  touchAvailable: true,
  precisePointerAvailable: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('importing an image', () {
    testWidgets('keeps the whole picture and opens a transform to place it', (
      tester,
    ) async {
      final (key, session) = await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1600, 900),
      );
      final state = session.editorState;
      final layersBefore = state.layerManager.layerCount;

      await tester.runAsync(() async {
        final png = await solidPng(1024, 256, const Color(0xFF00FF00));
        await key.currentState!.debugImportDroppedImageLayer('wide.png', png);
      });
      await settleLayerThumbnails(tester);

      final placed = state.layerManager.activeLayer!;
      expect(state.layerManager.layerCount, layersBefore + 1);
      expect(placed.name, 'wide.png');
      // 宽图等比缩小到取景框宽度，没有任何部分被裁掉
      expect(placed.contentBounds, const Rect.fromLTWH(0, 192, 512, 128));
      expect(state.currentTool, isA<MoveTool>());
      expect(state.layerTransformer.isActive, isTrue);
      expect(_sessionBar, findsOneWidget);

      await tester.tap(find.text('Cancel Transform'));
      await tester.pumpAndSettle();
      expect(state.layerManager.layerCount, layersBefore);
      expect(_sessionBar, findsNothing);
    });

    testWidgets('apply keeps the placed layer and closes the bar', (
      tester,
    ) async {
      final (key, session) = await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1180, 760),
      );
      final state = session.editorState;

      await tester.runAsync(() async {
        final png = await solidPng(64, 64, const Color(0xFF00FF00));
        await key.currentState!.debugImportDroppedImageLayer('tile.png', png);
      });
      await settleLayerThumbnails(tester);
      final placed = state.layerManager.activeLayer!;

      await tester.tap(find.text('Apply Transform'));
      await tester.pumpAndSettle();
      expect(state.layerTransformer.isActive, isFalse);
      expect(state.layerManager.getLayerById(placed.id), isNotNull);
      expect(placed.contentBounds, const Rect.fromLTWH(224, 224, 64, 64));
      expect(_sessionBar, findsNothing);
    });

    testWidgets('the layer panel offers a file import', (tester) async {
      await pumpEditorWorkspace(tester, viewSize: const Size(1600, 900));
      expect(find.byTooltip('Import Image'), findsOneWidget);
    });
  });

  group('move tool panel', () {
    testWidgets('numeric width scales from the center with the aspect lock', (
      tester,
    ) async {
      final (_, session) = await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1600, 900),
      );
      final state = session.editorState;
      final layer = await _addContentLayer(tester, state);
      state.setToolById(MoveTool.toolId);
      await tester.pumpAndSettle();

      await tester.enterText(_field(0), '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(layer.contentBounds, const Rect.fromLTWH(125, 125, 50, 50));
      expect(state.layerTransformer.isActive, isTrue);
      expect(_sessionBar, findsOneWidget);
      expect(find.text('50 × 50 px'), findsOneWidget);
    });

    testWidgets('flip buttons mirror inside the open transform', (
      tester,
    ) async {
      final (_, session) = await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1600, 900),
      );
      final state = session.editorState;
      await _addContentLayer(tester, state);
      state.setToolById(MoveTool.toolId);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Flip Horizontal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flip Horizontal'));
      await tester.pumpAndSettle();
      expect(state.layerTransformer.params!.scaleX, -1);
      expect(state.historyManager.undoStackSize, 2);
    });

    for (final viewSize in editorPanelViewSizes) {
      for (final textScale in [1.0, 3.0]) {
        testWidgets('fields stay reachable at ${viewSize.width.toInt()}px '
            'and ${textScale}x text', (tester) async {
          final (_, session) = await pumpEditorWorkspace(
            tester,
            viewSize: viewSize,
            textScale: textScale,
            policy: viewSize.width < 600
                ? _touchPolicy
                : const InteractionPolicy(
                    modality: InteractionModality.pointer,
                    touchAvailable: false,
                    precisePointerAvailable: true,
                  ),
          );
          await _addContentLayer(tester, session.editorState);
          session.editorState.setToolById(MoveTool.toolId);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(MoveToolPanel), findsOneWidget);
          for (final label in ['Width', 'Height', 'Angle', 'Center X']) {
            final field = find.descendant(
              of: find.byType(MoveToolPanel),
              matching: find.text(label),
            );
            await tester.ensureVisible(field.first);
            await tester.pumpAndSettle();
            expect(field, findsWidgets, reason: label);
          }
          await tester.ensureVisible(find.text('Flip Vertical'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

Finder get _sessionBar => find.byKey(const ValueKey('transform-session-bar'));

Finder _field(int index) => find
    .descendant(
      of: find.byType(MoveToolPanel),
      matching: find.byType(TextField),
    )
    .at(index);

Future<Layer> _addContentLayer(WidgetTester tester, EditorState state) async {
  final layer = state.layerCommands.addLayer(name: 'content');
  final image = await tester.runAsync(
    () => solidImage(100, 100, const Color(0xFFFF0000)),
  );
  state.layerManager.replaceLayerBaseImageSync(
    layer.id,
    image!,
    null,
    offset: const Offset(100, 100),
  );
  await tester.pumpAndSettle();
  return layer;
}
