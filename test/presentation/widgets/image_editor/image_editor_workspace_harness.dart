import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';

/// 工具面板响应式回归覆盖的窗口尺寸
const editorPanelViewSizes = [
  Size(320, 720),
  Size(600, 760),
  Size(840, 760),
  Size(1180, 760),
  Size(1600, 900),
];

/// 以普通编辑模式泵入工作区，按需切到 [toolId] 并等待布局稳定
Future<void> pumpEditorWorkspace(
  WidgetTester tester, {
  required Size viewSize,
  double textScale = 1,
  String locale = 'en',
  String? toolId,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewSize;
  addTearDown(tester.view.reset);

  final config = ImageEditorSessionConfig(
    initialSize: const Size(512, 512),
    debugOptions: const ImageEditorDebugOptions(disableDropRegion: true),
  );
  final session = ImageEditorController(config: config);
  addTearDown(session.dispose);
  final key = GlobalKey<ImageEditorWorkspaceState>();

  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
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

  if (toolId != null) {
    key.currentState!.debugSetToolById(toolId);
    await tester.pumpAndSettle();
    expect(key.currentState!.debugCurrentToolId, toolId);
  }
}
