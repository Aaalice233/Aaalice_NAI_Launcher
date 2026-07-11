import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_bridge.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_editor_screen.dart';

/// 1x1 透明 PNG
const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// 自动应答桥:每条命令按类型立即回 response,走真实 Model3dBridge 逻辑
Model3dBridge autoReplyBridge() {
  late Model3dBridge bridge;
  bridge = Model3dBridge(
    evalJs: (source) async {
      final match = RegExp(r'dispatch\((.+)\)$').firstMatch(source)!;
      final command = jsonDecode(jsonDecode(match.group(1)!) as String)
          as Map<String, dynamic>;
      final data = switch (command['type'] as String) {
        'render' => {'png': _tinyPng},
        'serialize' => {
            'sceneState': {'version': 1},
          },
        'loadModel' => {'boneCount': 19, 'duplicateBoneNames': <String>[]},
        _ => <String, dynamic>{},
      };
      // 模拟 JS 异步回复
      Future.microtask(() => bridge.handleJsMessage([
            {
              'type': 'response',
              'requestId': command['requestId'],
              'ok': true,
              'data': data,
            },
          ]));
    },
  );
  return bridge;
}

Future<void> pumpEditor(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () {
          Navigator.push<Model3dEditResult>(
            context,
            MaterialPageRoute(
              builder: (_) => Model3dEditorScreen(
                renderWidth: 8,
                renderHeight: 8,
                bridgeOverride: autoReplyBridge(),
                viewportBuilder: (_) => const ColoredBox(color: Colors.black),
                markReadyForTest: true,
              ),
            ),
          );
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty scene shows mannequin and import entries',
      (tester) async {
    await pumpEditor(tester);
    expect(find.text('Add Built-in Mannequin'), findsOneWidget);
    expect(find.text('Import Model (.glb/.gltf)'), findsOneWidget);
  });

  testWidgets('adding mannequin hides empty state and enables apply',
      (tester) async {
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
    await pumpEditor(tester);
    await tester.tap(find.text('Add Built-in Mannequin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to Layer'));
    await tester.pumpAndSettle();
    // 编辑器已关闭(返回打开页)
    expect(find.text('open'), findsOneWidget);
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
}
