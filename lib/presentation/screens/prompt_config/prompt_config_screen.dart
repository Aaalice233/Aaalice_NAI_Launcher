import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/prompt/random_manager/preset_selector_bar.dart';
import '../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../widgets/prompt/random_manager/probability_chart.dart';
import '../../widgets/prompt/random_manager/category_card.dart';

/// 随机提示词配置页面 - 左右分栏布局
///
/// 布局结构:
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   PresetSelectorBar                          │
/// ├──────────────────────┬──────────────────────────────────────┤
/// │  AlgorithmConfigCard │         CategoryCardList              │
/// │                      │   ┌────────────────────────────────┐  │
/// │  ProbabilitySection  │   │ Category 1                     │  │
/// │                      │   ├────────────────────────────────┤  │
/// │                      │   │ Category 2                     │  │
/// │                      │   ├────────────────────────────────┤  │
/// │                      │   │ Category 3                     │  │
/// │                      │   └────────────────────────────────┘  │
/// └──────────────────────┴──────────────────────────────────────┘
class PromptConfigScreen extends ConsumerWidget {
  const PromptConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          // 预设选择栏
          const Padding(
            padding: EdgeInsets.all(16),
            child: PresetSelectorBar(),
          ),

          // 主内容区 - 左右分栏
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;

                if (isWide) {
                  // 宽屏: 左右分栏布局
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧: 算法配置 + 概率分布预览
                        SizedBox(
                          width: 420,
                          child: _LeftPanel(),
                        ),
                        SizedBox(width: 16),
                        // 右侧: 类别配置垂直列表
                        Expanded(
                          child: CategoryCardList(),
                        ),
                      ],
                    ),
                  );
                } else {
                  // 窄屏: 上下布局
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AlgorithmConfigCard(),
                        const SizedBox(height: 16),
                        const ProbabilitySection(),
                        const SizedBox(height: 16),
                        Divider(
                          color: colorScheme.outlineVariant.withOpacity(0.3),
                          height: 1,
                        ),
                        const SizedBox(height: 16),
                        const CategoryCardGrid(),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 左侧面板 - 算法配置 + 概率分布预览
class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 算法配置卡片
          AlgorithmConfigCard(),
          SizedBox(height: 16),
          // 概率分布预览
          ProbabilitySection(),
        ],
      ),
    );
  }
}
