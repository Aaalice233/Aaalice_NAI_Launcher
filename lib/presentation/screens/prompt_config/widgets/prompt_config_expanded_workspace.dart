import 'package:flutter/material.dart';

import '../../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../../widgets/prompt/random_manager/preview_generator_panel.dart';

/// 宽屏工作区：配方列表与右侧检查栏（算法设置与预览）并排
class PromptConfigExpandedWorkspace extends StatelessWidget {
  const PromptConfigExpandedWorkspace({
    super.key,
    required this.categoryList,
    required this.inspectorWidth,
    required this.onGlobalSettings,
    required this.previewController,
  });

  final Widget categoryList;
  final double inspectorWidth;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: categoryList),
          const SizedBox(width: 16),
          _InspectorPanel(
            width: inspectorWidth,
            onGlobalSettings: onGlobalSettings,
            previewController: previewController,
          ),
        ],
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.width,
    required this.onGlobalSettings,
    required this.previewController,
  });

  final double width;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final setup = <Widget>[
            AlgorithmConfigCard(onGlobalSettings: onGlobalSettings),
            const SizedBox(height: 16),
          ];
          if (constraints.maxHeight < 620) {
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              children: [
                ...setup,
                PreviewGeneratorPanel(
                  controller: previewController,
                  inline: true,
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...setup,
              Expanded(
                child: PreviewGeneratorPanel(controller: previewController),
              ),
            ],
          );
        },
      ),
    );
  }
}
