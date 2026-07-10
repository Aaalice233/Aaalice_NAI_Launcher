import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import 'comfyui_settings_section.dart';
import 'krita_bridge_settings_section.dart';
import 'prompt_assistant_settings_section.dart';

/// 集成设置板块
///
/// 汇总外部工具集成（Prompt Assistant / ComfyUI / Krita）。
/// 顶部子导航切换，一次只渲染一个面板，避免长滚动页。
class IntegrationsSettingsSection extends StatefulWidget {
  /// 测试注入用面板构造器；非 null 时必须恰好包含三个构造器。
  ///
  /// 生产环境保持 null 使用默认三面板。
  @visibleForTesting
  final List<WidgetBuilder>? panelBuilders;

  const IntegrationsSettingsSection({super.key, this.panelBuilders})
    : assert(
        panelBuilders == null || panelBuilders.length == 3,
        'panelBuilders must contain exactly three builders.',
      );

  @override
  State<IntegrationsSettingsSection> createState() =>
      _IntegrationsSettingsSectionState();
}

class _IntegrationsSettingsSectionState
    extends State<IntegrationsSettingsSection> {
  int _selectedIndex = 0;

  List<WidgetBuilder> get _builders =>
      widget.panelBuilders ??
      [
        (_) => const PromptAssistantSettingsSection(),
        (_) => const ComfyUISettingsSection(),
        (_) => const KritaBridgeSettingsSection(),
      ];

  @override
  Widget build(BuildContext context) {
    final labels = [context.l10n.settings_promptAssistant, 'ComfyUI', 'Krita'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < labels.length; i++)
                  ButtonSegment(value: i, label: Text(labels[i])),
              ],
              selected: {_selectedIndex},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _selectedIndex = selection.first);
              },
            ),
          ),
        ),
        _builders[_selectedIndex](context),
      ],
    );
  }
}
