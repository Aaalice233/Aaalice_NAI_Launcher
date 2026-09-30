import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/compact_control_metrics.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/horizontal_segmented_control.dart';
import '../../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../../widgets/prompt/random_manager/preview_generator_panel.dart';
import 'prompt_config_workspace_slivers.dart';

/// 紧凑工作区：配方、预览、算法三个分区切换，标题栏与分区切换随当前分区滚动
class PromptConfigCompactWorkspace extends StatefulWidget {
  const PromptConfigCompactWorkspace({
    super.key,
    required this.header,
    required this.recipeBuilder,
    required this.onGlobalSettings,
    required this.previewController,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final Widget header;
  final Widget Function(List<Widget> leadingSlivers) recipeBuilder;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;
  final int selectedSection;
  final ValueChanged<int> onSectionSelected;

  @override
  State<PromptConfigCompactWorkspace> createState() =>
      _PromptConfigCompactWorkspaceState();
}

class _PromptConfigCompactWorkspaceState
    extends State<PromptConfigCompactWorkspace> {
  // 标题栏与分区切换只放在当前分区的滚动视图里，换分区时整体迁移并保留焦点
  final _chromeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final chrome = PromptConfigChromeSliver(
      child: KeyedSubtree(
        key: _chromeKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.header,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: HorizontalSegmentedControl(
                child: _SectionSwitcher(
                  selectedSection: widget.selectedSection,
                  onSectionSelected: widget.onSectionSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    List<Widget> leadingFor(int section) =>
        section == widget.selectedSection ? [chrome] : const [];

    return IndexedStack(
      index: widget.selectedSection,
      children: [
        widget.recipeBuilder(leadingFor(0)),
        PromptConfigSectionScrollView(
          slivers: [
            ...leadingFor(1),
            _SectionBodySliver(
              child: PreviewGeneratorPanel(
                controller: widget.previewController,
                inline: true,
              ),
            ),
          ],
        ),
        PromptConfigSectionScrollView(
          slivers: [
            ...leadingFor(2),
            _SectionBodySliver(
              child: AlgorithmConfigCard(
                onGlobalSettings: widget.onGlobalSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionSwitcher extends StatelessWidget {
  const _SectionSwitcher({
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final int selectedSection;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      key: const ValueKey('random-manager-compact-sections'),
      segments: [
        ButtonSegment(
          value: 0,
          icon: const Icon(Icons.layers_outlined, size: 17),
          label: Text(context.l10n.randomManager_recipeTitle),
        ),
        ButtonSegment(
          value: 1,
          icon: const Icon(Icons.preview_outlined, size: 17),
          label: Text(context.l10n.randomManager_previewGeneration),
        ),
        ButtonSegment(
          value: 2,
          icon: const Icon(Icons.tune_rounded, size: 17),
          label: Text(context.l10n.randomManager_inspectorTitle),
        ),
      ],
      selected: {selectedSection},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSectionSelected(selection.first),
      // 触屏保留 48 高的命中区，精确指针下维持紧凑
      style: ButtonStyle(
        visualDensity: CompactControlMetrics.forPolicy(
          context.interactionPolicy,
        ).density,
      ),
    );
  }
}

class _SectionBodySliver extends StatelessWidget {
  const _SectionBodySliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}
