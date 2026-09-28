import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/model3d_layer_data.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_bridge.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_editor_screen.dart';

/// 1x1 透明 PNG
const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// 自动应答桥:每条命令按类型立即回 response,走真实 Model3dBridge 逻辑
Model3dBridge autoReplyBridge({List<Map<String, dynamic>>? recordedCommands}) {
  late Model3dBridge bridge;
  bridge = Model3dBridge(
    evalJs: (source) async {
      final match = RegExp(r'dispatch\((.+)\)$').firstMatch(source)!;
      final command =
          jsonDecode(jsonDecode(match.group(1)!) as String)
              as Map<String, dynamic>;
      recordedCommands?.add(command);
      final data = switch (command['type'] as String) {
        'render' => {'png': _tinyPng},
        'serialize' => {
          'sceneState': {'version': 1},
        },
        'loadModel' => {'boneCount': 19, 'duplicateBoneNames': <String>[]},
        _ => <String, dynamic>{},
      };
      // 模拟 JS 异步回复
      Future.microtask(
        () => bridge.handleJsMessage([
          {
            'type': 'response',
            'requestId': command['requestId'],
            'ok': true,
            'data': data,
          },
        ]),
      );
    },
  );
  return bridge;
}

/// 打开编辑器,返回 Navigator.push 的结果 Future(供断言 pop 返回值)
Future<Future<Model3dEditResult?>> pumpEditor(
  WidgetTester tester, {
  Model3dLayerData? existing,
  Model3dBridge? bridge,
  Size size = const Size(800, 600),
  double textScale = 1,
  double? contentWidth,
}) async {
  late Future<Model3dEditResult?> resultFuture;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 12, bottom: 16),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            resultFuture = Navigator.push<Model3dEditResult>(
              context,
              MaterialPageRoute(
                builder: (_) {
                  final editor = Model3dEditorScreen(
                    renderWidth: 8,
                    renderHeight: 8,
                    existing: existing,
                    bridgeOverride: bridge ?? autoReplyBridge(),
                    viewportBuilder: (_) =>
                        const ColoredBox(color: Colors.black),
                    markReadyForTest: true,
                  );
                  return Align(
                    child: SizedBox(width: contentWidth, child: editor),
                  );
                },
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return resultFuture;
}

void main() {
  testWidgets('narrow large-text editor keeps primary actions reachable', (
    tester,
  ) async {
    const size = Size(360, 640);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpEditor(tester, size: size, textScale: 2);

    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.text('Add Built-in Mannequin'), findsOneWidget);
    expect(find.text('Import Model (.glb/.gltf)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'light fields stay usable at 320px, 3x text, SafeArea and bridge live updates',
    (tester) async {
      const size = Size(320, 900);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final commands = <Map<String, dynamic>>[];
      await pumpEditor(
        tester,
        size: size,
        textScale: 3,
        bridge: autoReplyBridge(recordedCommands: commands),
      );

      final toolbarScroll = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      for (
        var attempt = 0;
        attempt < 6 &&
            find
                .byIcon(Icons.accessibility_new)
                .hitTestable()
                .evaluate()
                .isEmpty;
        attempt++
      ) {
        await tester.drag(toolbarScroll, const Offset(-240, 0));
        await tester.pumpAndSettle();
      }
      expect(
        find.byIcon(Icons.accessibility_new).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.accessibility_new).hitTestable());
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 6 &&
            find.byIcon(Icons.light_mode).hitTestable().evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(toolbarScroll, const Offset(240, 0));
        await tester.pumpAndSettle();
      }
      expect(find.byIcon(Icons.light_mode).hitTestable(), findsOneWidget);
      await tester.tap(find.byIcon(Icons.light_mode).hitTestable());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('model3d-light-intensity')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('model3d-light-azimuth')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('model3d-light-elevation')),
        findsOneWidget,
      );

      final intensitySlider = find.descendant(
        of: find.byKey(const ValueKey('model3d-light-intensity')),
        matching: find.byType(Slider),
      );
      await tester.drag(intensitySlider, const Offset(40, 0));
      await tester.pumpAndSettle();

      final lightCommands = commands
          .where((command) => command['type'] == 'setLight')
          .toList();
      expect(lightCommands, isNotEmpty);
      final payload = lightCommands.last;
      expect(payload['intensity'], isNot(1.6));
      expect(payload['azimuth'], 37.0);
      expect(payload['elevation'], 50.0);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    },
  );

  testWidgets('apply action uses the editor local width', (tester) async {
    const size = Size(800, 640);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpEditor(tester, size: size, contentWidth: 500);

    final appBar = find.byType(AppBar);
    expect(
      find.descendant(
        of: appBar,
        matching: find.widgetWithText(FilledButton, 'Apply to Layer'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty scene shows mannequin and import entries', (tester) async {
    await pumpEditor(tester);
    expect(find.text('Add Built-in Mannequin'), findsOneWidget);
    expect(find.text('Import Model (.glb/.gltf)'), findsOneWidget);
  });

  testWidgets('adding mannequin hides empty state and enables apply', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Add Built-in Mannequin'));
    await tester.pumpAndSettle();
    expect(find.text('Add Built-in Mannequin'), findsNothing);
    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply to Layer'),
    );
    expect(applyButton.onPressed, isNotNull);
  });

  testWidgets('apply pops with png, sceneState and modelRef', (tester) async {
    final resultFuture = await pumpEditor(tester);
    await tester.tap(find.text('Add Built-in Mannequin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to Layer'));
    await tester.pumpAndSettle();
    // 编辑器已关闭(返回打开页)
    expect(find.text('open'), findsOneWidget);
    final result = await resultFuture;
    expect(result, isNotNull);
    expect(result!.pngBytes, isNotEmpty);
    expect(result.modelRef, 'builtin:mannequin');
    expect(result.sceneState['version'], 1);
  });

  testWidgets('back with dirty scene asks confirmation', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Add Built-in Mannequin'));
    await tester.pumpAndSettle();
    // loadModel 后编辑器视为脏(内容尚未应用)
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unapplied changes?'), findsOneWidget);
  });

  testWidgets('bridge timeout surfaces a snackbar', (tester) async {
    // evalJs 从不回复,模拟 JS 侧卡死/无响应,驱动 Model3dBridge 的 15s
    // 超时路径(此处缩短为 100ms 以加快测试)。
    await pumpEditor(
      tester,
      bridge: Model3dBridge(
        evalJs: (_) async {},
        timeout: const Duration(milliseconds: 100),
      ),
    );
    await tester.tap(find.text('Add Built-in Mannequin'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('existing builtin layer restores without dirty', (tester) async {
    await pumpEditor(
      tester,
      existing: const Model3dLayerData(
        modelRef: 'builtin:mannequin',
        sceneState: {'version': 1},
      ),
    );
    // 恢复完成:人偶已自动加载,空态卡片不再显示
    expect(find.text('Add Built-in Mannequin'), findsNothing);
    // 恢复不置脏:返回应直接关闭,不出现放弃确认
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unapplied changes?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
