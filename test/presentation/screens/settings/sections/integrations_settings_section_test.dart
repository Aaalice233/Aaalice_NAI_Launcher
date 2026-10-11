import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';

const _modelServicesPanelKey = ValueKey<String>('panel-model-services');
const _promptAssistantPanelKey = ValueKey<String>('panel-prompt-assistant');
const _comfyUiPanelKey = ValueKey<String>('panel-comfyui');
const _kritaPanelKey = ValueKey<String>('panel-krita');
const _mcpPanelKey = ValueKey<String>('panel-mcp');
const _panelKeys = [
  _modelServicesPanelKey,
  _promptAssistantPanelKey,
  _comfyUiPanelKey,
  _kritaPanelKey,
  _mcpPanelKey,
];

class _PanelProbe extends StatefulWidget {
  const _PanelProbe({
    required super.key,
    required this.label,
    required this.onDispose,
  });

  final String label;
  final VoidCallback onDispose;

  @override
  State<_PanelProbe> createState() => _PanelProbeState();
}

class _PanelProbeState extends State<_PanelProbe> {
  @override
  Widget build(BuildContext context) => Text(widget.label);

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

void main() {
  Future<void> pumpSection(
    WidgetTester tester,
    List<String> disposedPanels, {
    Locale locale = const Locale('zh'),
    TargetPlatform targetPlatform = TargetPlatform.windows,
    Size size = const Size(800, 600),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = targetPlatform;
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: IntegrationsSettingsSection(
                panelBuilders: {
                  IntegrationPanel.modelServices: (_) => _PanelProbe(
                    key: _modelServicesPanelKey,
                    label: 'panel-model-services',
                    onDispose: () => disposedPanels.add('model-services'),
                  ),
                  IntegrationPanel.promptAssistant: (_) => _PanelProbe(
                    key: _promptAssistantPanelKey,
                    label: 'panel-prompt-assistant',
                    onDispose: () => disposedPanels.add('prompt-assistant'),
                  ),
                  IntegrationPanel.comfyUi: (_) => _PanelProbe(
                    key: _comfyUiPanelKey,
                    label: 'panel-comfyui',
                    onDispose: () => disposedPanels.add('comfyui'),
                  ),
                  IntegrationPanel.krita: (_) => _PanelProbe(
                    key: _kritaPanelKey,
                    label: 'panel-krita',
                    onDispose: () => disposedPanels.add('krita'),
                  ),
                  IntegrationPanel.mcp: (_) => _PanelProbe(
                    key: _mcpPanelKey,
                    label: 'panel-mcp',
                    onDispose: () => disposedPanels.add('mcp'),
                  ),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  void expectOnlyPanel(ValueKey<String> expectedKey) {
    for (final panelKey in _panelKeys) {
      expect(
        find.byKey(panelKey, skipOffstage: false),
        panelKey == expectedKey ? findsOneWidget : findsNothing,
      );
    }
  }

  test('测试注入面板必须恰好覆盖 DLSS 以外的五个面板', () {
    Widget buildPanel(BuildContext _) => const SizedBox.shrink();
    final panels = IntegrationsSettingsSection.injectablePanels.toList();

    for (final invalidLength in [0, 1, 2, 3, 4]) {
      expect(
        () => IntegrationsSettingsSection(
          panelBuilders: {
            for (final panel in panels.take(invalidLength)) panel: buildPanel,
          },
        ),
        throwsAssertionError,
        reason: 'panelBuilders length $invalidLength should be rejected',
      );
    }

    expect(
      () => IntegrationsSettingsSection(
        panelBuilders: {for (final panel in panels) panel: buildPanel},
      ),
      returnsNormally,
    );
    expect(() => const IntegrationsSettingsSection(), returnsNormally);
  });

  testWidgets('默认显示模型服务且五段可切换', (tester) async {
    final disposedPanels = <String>[];
    await pumpSection(tester, disposedPanels);

    expect(find.text('模型服务'), findsOneWidget);
    expect(find.text('提示词助手'), findsOneWidget);
    expect(find.text('ComfyUI'), findsOneWidget);
    expect(find.text('Krita'), findsOneWidget);
    expect(find.text('MCP'), findsOneWidget);

    // 从完整元素树确认默认只挂载第一个面板。
    expectOnlyPanel(_modelServicesPanelKey);
    expect(disposedPanels, isEmpty);

    await tester.tap(find.text('提示词助手'));
    await tester.pumpAndSettle();
    expectOnlyPanel(_promptAssistantPanelKey);
    expect(disposedPanels, ['model-services']);

    await tester.tap(find.text('ComfyUI'));
    await tester.pumpAndSettle();
    expectOnlyPanel(_comfyUiPanelKey);
    expect(disposedPanels, ['model-services', 'prompt-assistant']);

    await tester.tap(find.text('Krita'));
    await tester.pumpAndSettle();
    expectOnlyPanel(_kritaPanelKey);

    await tester.tap(find.text('MCP'));
    await tester.pumpAndSettle();
    expectOnlyPanel(_mcpPanelKey);
    expect(disposedPanels, [
      'model-services',
      'prompt-assistant',
      'comfyui',
      'krita',
    ]);
  });

  testWidgets('英文环境切换集成面板时分段导航总宽度保持不变', (tester) async {
    final disposedPanels = <String>[];
    await pumpSection(tester, disposedPanels, locale: const Locale('en'));

    final segmentedButton = find.byType(SegmentedButton<IntegrationPanel>);
    final modelServicesWidth = tester.getSize(segmentedButton).width;

    await tester.tap(find.text('Prompt Assistant'));
    await tester.pumpAndSettle();
    final promptAssistantWidth = tester.getSize(segmentedButton).width;

    await tester.tap(find.text('ComfyUI'));
    await tester.pumpAndSettle();
    final comfyUiWidth = tester.getSize(segmentedButton).width;

    await tester.tap(find.text('Krita'));
    await tester.pumpAndSettle();
    final kritaWidth = tester.getSize(segmentedButton).width;

    await tester.tap(find.text('MCP'));
    await tester.pumpAndSettle();
    final mcpWidth = tester.getSize(segmentedButton).width;

    expect(
      [promptAssistantWidth, comfyUiWidth, kritaWidth, mcpWidth],
      everyElement(modelServicesWidth),
      reason:
          'Model services=$modelServicesWidth, '
          'Prompt Assistant=$promptAssistantWidth, '
          'ComfyUI=$comfyUiWidth, Krita=$kritaWidth, MCP=$mcpWidth',
    );
  });

  testWidgets('Android 保留但禁用 ComfyUI 分段入口', (tester) async {
    final disposedPanels = <String>[];
    await pumpSection(
      tester,
      disposedPanels,
      targetPlatform: TargetPlatform.android,
    );

    final segmentedButton = tester.widget<SegmentedButton<IntegrationPanel>>(
      find.byType(SegmentedButton<IntegrationPanel>),
    );
    final comfyUi = segmentedButton.segments.singleWhere(
      (segment) => segment.value == IntegrationPanel.comfyUi,
    );
    expect(comfyUi.enabled, isFalse);
    expect(comfyUi.tooltip, '仅桌面端可用');

    await tester.tap(find.text('ComfyUI'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expectOnlyPanel(_modelServicesPanelKey);
    expect(disposedPanels, isEmpty);
  });

  for (final width in [320.0, 600.0, 840.0, 1600.0]) {
    testWidgets('集成分段导航在 ${width.toInt()} 宽度可滚动且无溢出', (tester) async {
      await pumpSection(
        tester,
        <String>[],
        size: Size(width, 420),
        textScale: width == 320 ? 3 : 1,
      );

      expect(find.byType(SegmentedButton<IntegrationPanel>), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  const expectedLabels = <String, List<String>>{
    'en': ['Model services', 'Prompt Assistant', 'ComfyUI', 'Krita', 'MCP'],
    'zh': ['模型服务', '提示词助手', 'ComfyUI', 'Krita', 'MCP'],
    'ja': ['モデルサービス', 'プロンプトアシスタント', 'ComfyUI', 'Krita', 'MCP'],
  };

  for (final entry in expectedLabels.entries) {
    testWidgets('分段导航按 ${entry.key} 显示精确文案', (tester) async {
      await pumpSection(tester, <String>[], locale: Locale(entry.key));

      final segmentedButton = tester.widget<SegmentedButton<IntegrationPanel>>(
        find.byType(SegmentedButton<IntegrationPanel>),
      );
      final labels = segmentedButton.segments
          .map((segment) => (segment.label as Text).data)
          .toList();

      expect(labels, entry.value, reason: 'locale=${entry.key}');
    });
  }
}
