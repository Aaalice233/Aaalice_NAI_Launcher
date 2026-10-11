import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/utils/localization_extension.dart';
import 'comfyui_settings_section.dart';
import '../../dlss/dlss_settings_section.dart';
import 'krita_bridge_settings_section.dart';
import 'mcp_server_settings_section.dart';
import 'model_services/model_services_settings_section.dart';
import 'prompt_assistant_settings_section.dart';
import '../widgets/settings_page_layout.dart';

enum IntegrationPanel {
  modelServices,
  promptAssistant,
  comfyUi,
  krita,
  mcp,
  dlss,
}

/// 集成设置板块
///
/// 汇总平台支持的外部工具与本地增强集成。
/// 顶部子导航切换，一次只渲染一个面板，避免长滚动页。
class IntegrationsSettingsSection extends StatefulWidget {
  /// 测试注入用面板构造器；非 null 时必须恰好覆盖 DLSS 以外的全部面板。
  ///
  /// 生产环境保持 null，按平台能力提供面板。
  @visibleForTesting
  final Map<IntegrationPanel, WidgetBuilder>? panelBuilders;

  final bool initiallyShowDlss;

  static const injectablePanels = {
    IntegrationPanel.modelServices,
    IntegrationPanel.promptAssistant,
    IntegrationPanel.comfyUi,
    IntegrationPanel.krita,
    IntegrationPanel.mcp,
  };

  const IntegrationsSettingsSection({
    super.key,
    this.panelBuilders,
    this.initiallyShowDlss = false,
  }) : assert(
         panelBuilders == null || panelBuilders.length == 5,
         'panelBuilders must cover every panel except DLSS.',
       );

  @override
  State<IntegrationsSettingsSection> createState() =>
      _IntegrationsSettingsSectionState();
}

class _IntegrationsSettingsSectionState
    extends State<IntegrationsSettingsSection> {
  // 跨紧凑断点时设置页会重建内容子树，当前分页存进路由级 PageStorage 才不会丢。
  static const _storageId = 'integrations-selected-panel';

  late final PlatformCapabilities _capabilities = PlatformCapabilities.current;
  late IntegrationPanel _selected;

  @override
  void initState() {
    super.initState();
    final stored = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _storageId);
    _selected = widget.initiallyShowDlss && _showDlss
        ? IntegrationPanel.dlss
        : stored is IntegrationPanel
        ? stored
        : IntegrationPanel.modelServices;
  }

  @override
  void didUpdateWidget(covariant IntegrationsSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyShowDlss && !oldWidget.initiallyShowDlss && _showDlss) {
      _select(IntegrationPanel.dlss);
    }
  }

  void _select(IntegrationPanel panel) {
    _selected = panel;
    PageStorage.maybeOf(
      context,
    )?.writeState(context, panel, identifier: _storageId);
  }

  bool get _injected => widget.panelBuilders != null;

  bool get _showDlss => !_injected && _capabilities.supportsDlssEnhancement;

  bool _visible(IntegrationPanel panel) => switch (panel) {
    IntegrationPanel.krita => _injected || _capabilities.supportsKritaBridge,
    IntegrationPanel.mcp => _injected || _capabilities.supportsMcpServer,
    IntegrationPanel.dlss => _showDlss,
    _ => true,
  };

  // ComfyUI 在移动端保留入口但禁用，让用户知道它存在且仅桌面可用。
  bool _enabled(IntegrationPanel panel) =>
      panel != IntegrationPanel.comfyUi ||
      _capabilities.supportsComfyUiIntegration;

  String _label(BuildContext context, IntegrationPanel panel) =>
      switch (panel) {
        IntegrationPanel.modelServices => context.l10n.settings_modelServices,
        IntegrationPanel.promptAssistant =>
          context.l10n.settings_promptAssistant,
        IntegrationPanel.comfyUi => 'ComfyUI',
        IntegrationPanel.krita => 'Krita',
        IntegrationPanel.mcp => 'MCP',
        IntegrationPanel.dlss => 'DLSSNR',
      };

  Widget _build(BuildContext context, IntegrationPanel panel) {
    final injected = widget.panelBuilders?[panel];
    if (injected != null) return injected(context);
    return switch (panel) {
      IntegrationPanel.modelServices => const ModelServicesSettingsSection(),
      IntegrationPanel.promptAssistant =>
        const PromptAssistantSettingsSection(),
      IntegrationPanel.comfyUi => const ComfyUISettingsSection(),
      IntegrationPanel.krita => const KritaBridgeSettingsSection(),
      IntegrationPanel.mcp => const McpServerSettingsSection(),
      IntegrationPanel.dlss => const DlssSettingsSection(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final panels = IntegrationPanel.values.where(_visible).toList();
    final selected = panels.contains(_selected) && _enabled(_selected)
        ? _selected
        : panels.first;

    return SettingsPageLayout(
      title: context.l10n.settings_integrations,
      children: [
        HorizontalActionStrip(
          child: SegmentedButton<IntegrationPanel>(
            segments: [
              for (final panel in panels)
                ButtonSegment(
                  value: panel,
                  enabled: _enabled(panel),
                  tooltip: _enabled(panel)
                      ? null
                      : context.l10n.settings_comfyUiDesktopOnly,
                  label: Text(_label(context, panel)),
                ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final next = selection.first;
              if (!_enabled(next)) return;
              setState(() => _select(next));
            },
          ),
        ),
        _build(context, selected),
      ],
    );
  }
}
