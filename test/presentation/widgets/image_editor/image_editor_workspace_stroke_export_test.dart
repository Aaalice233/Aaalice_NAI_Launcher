import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_base.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('exporting right after a blur stroke includes that stroke', (
    tester,
  ) async {
    final editor = await _pushEditor(tester);
    final state = editor.state;
    final blur = editor.selectTool('blur');

    _drag(blur, state, const [Offset(24, 16), Offset(40, 16)]);
    final result = await editor.exportNow(tester);

    final pixel = result.getPixel(30, 16);
    expect(pixel.r, inExclusiveRange(0, 255), reason: '红蓝交界被模糊');
    expect(pixel.b, inExclusiveRange(0, 255));
  });

  testWidgets('exporting right after a fill tap waits for that fill', (
    tester,
  ) async {
    final editor = await _pushEditor(tester);
    final state = editor.state;
    state.setForegroundColor(const Color(0xFF00FF00));
    final fill = editor.selectTool('fill');

    _drag(fill, state, const [Offset(48, 48)]);
    expect(state.historyManager.canUndo, isFalse, reason: '填充仍在回读');
    final result = await editor.exportNow(tester);

    final pixel = result.getPixel(48, 48);
    expect(pixel.g, greaterThan(100), reason: '导出包含刚才的填充');
    final untouched = result.getPixel(16, 16);
    expect((untouched.r, untouched.g, untouched.b), (255, 0, 0));
  });
}

class _Editor {
  _Editor(this.state, this._workspace, this._result);

  final EditorState state;
  final ImageEditorWorkspaceState _workspace;
  final Future<ImageEditorResult?> _result;

  EditorTool selectTool(String id) {
    _workspace.debugSetToolById(id);
    return state.currentTool!;
  }

  /// 松手后不做任何等待直接导出，返回导出的合成图
  Future<img.Image> exportNow(WidgetTester tester) async {
    ImageEditorResult? exported;
    var completed = false;
    _result.then((value) {
      exported = value;
      completed = true;
    });
    _workspace.debugExportAndClose();
    for (var i = 0; i < 200 && !completed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(completed, isTrue, reason: '导出在时限内完成');
    return img.decodePng(exported!.modifiedImage!)!;
  }
}

Future<_Editor> _pushEditor(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1180, 760);
  addTearDown(tester.view.reset);

  final config = ImageEditorSessionConfig(
    initialSize: const Size(64, 64),
    debugOptions: const ImageEditorDebugOptions(disableDropRegion: true),
  );
  final session = ImageEditorController(config: config);
  addTearDown(session.dispose);
  final key = GlobalKey<ImageEditorWorkspaceState>();
  final navigator = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const SizedBox.shrink(),
    ),
  );
  final result = navigator.currentState!.push<ImageEditorResult>(
    MaterialPageRoute(
      builder: (_) => InteractionPolicyScope(
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

  final state = session.editorState;
  final layer = state.layerManager.activeLayer!;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 32, 64),
      Paint()..color = const Color(0xFFFF0000),
    );
    canvas.drawRect(
      const Rect.fromLTWH(32, 0, 32, 64),
      Paint()..color = const Color(0xFF0000FF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    picture.dispose();
    state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);
  });
  await tester.pump();
  return _Editor(state, key.currentState!, result);
}

void _drag(EditorTool tool, EditorState state, List<Offset> points) {
  tool.onPointerDown(PointerDownEvent(position: points.first), state);
  for (final point in points.skip(1)) {
    tool.onPointerMove(PointerMoveEvent(position: point), state);
  }
  tool.onPointerUp(PointerUpEvent(position: points.last), state);
}
