import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/workflow_template.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/comfyui_workflow_dialog.dart';

void main() {
  testWidgets('320dp、3x 字号、IME 和 SafeArea 下全屏表单保留执行结果语义', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<Uint8List>? returnedResults;
    await tester.pumpWidget(
      _buildApp(
        size: const Size(320, 800),
        textScale: 3,
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
        viewInsets: const EdgeInsets.only(bottom: 220),
        onResult: (results) => returnedResults = results,
      ),
    );
    await tester.pump();
    expect(find.text('打开').hitTestable(), findsOneWidget);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ComfyUIWorkflowDialog), findsOneWidget);

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.text('采样器'), findsOneWidget);

    final execute = find.text('执行');
    await tester.ensureVisible(execute);
    await tester.tap(execute);
    await tester.pump();

    for (final label in const ['使用结果', '关闭', '执行']) {
      expect(find.text(label), findsOneWidget);
    }
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
    );
    expect(panelRect.top, greaterThanOrEqualTo(24));
    expect(panelRect.bottom, lessThanOrEqualTo(580));
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('使用结果'));
    await tester.tap(find.text('使用结果'));
    await tester.pumpAndSettle();
    expect(find.byType(ComfyUIWorkflowDialog), findsNothing);
    expect(returnedResults, hasLength(1));
  });

  testWidgets('宽屏工作流表单使用有界侧栏并保留动态槽位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        size: const Size(1600, 900),
        textScale: 1,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
    );
    expect(find.text('打开').hitTestable(), findsOneWidget);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ComfyUIWorkflowDialog), findsOneWidget);

    final panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThanOrEqualTo(560));
    expect(find.text('采样器'), findsOneWidget);
    expect(find.text('Euler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildApp({
  required Size size,
  required double textScale,
  required EdgeInsets padding,
  required EdgeInsets viewInsets,
  ValueChanged<List<Uint8List>?>? onResult,
}) {
  return ProviderScope(
    overrides: [comfyUITaskProvider.overrideWith(_SuccessfulComfyUITask.new)],
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewInsets: viewInsets,
          devicePixelRatio: 3,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final results = await ComfyUIWorkflowDialog.show(
                  context,
                  template: _template,
                );
                onResult?.call(results);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
}

const _template = WorkflowTemplate(
  id: 'responsive-workflow',
  name: '响应式工作流',
  description: '测试窄屏、软键盘与宽屏下的动态参数',
  slots: [
    WorkflowSlot(
      id: 'sampler',
      label: '采样器',
      direction: SlotDirection.parameter,
      dataType: SlotDataType.choice,
      nodeId: '1',
      choices: ['Euler', 'DPM++'],
      defaultValue: 'Euler',
    ),
  ],
  workflowJson: {},
);

class _SuccessfulComfyUITask extends ComfyUITask {
  @override
  ComfyUITaskState build() => const ComfyUITaskState();

  @override
  Future<List<Uint8List>?> execute({
    required String templateId,
    Map<String, Uint8List> inputImages = const {},
    Map<String, dynamic> paramValues = const {},
  }) async {
    return [
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ];
  }
}
