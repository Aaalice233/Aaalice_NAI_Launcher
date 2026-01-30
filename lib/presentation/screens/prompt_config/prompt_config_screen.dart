import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/prompt/random_manager/preset_selector_bar.dart';
import '../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../widgets/prompt/random_manager/probability_chart.dart';
import '../../widgets/prompt/random_manager/category_card.dart';

/// 随机提示词配置页面 - 仪表盘布局
///
/// 布局结构:
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   PresetSelectorBar                          │
/// ├───────────────────────────────┬─────────────────────────────┤
/// │    AlgorithmConfigCard        │    ProbabilityChart          │
/// │    (角色数量/性别权重/全局)    │    (概率分布可视化)          │
/// ├───────────────────────────────┴─────────────────────────────┤
/// │                    CategoryCardGrid                          │
/// │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
/// │  │Category │ │Category │ │Category │ │Category │  ...       │
/// │  │  Card   │ │  Card   │ │  Card   │ │  Card   │           │
/// │  └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
/// └─────────────────────────────────────────────────────────────┘
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

          // 可滚动内容区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 算法配置区域 (左: 配置卡片, 右: 概率图表)
                  const _AlgorithmSection(),

                  const SizedBox(height: 16),

                  // 分隔线
                  Divider(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                    height: 1,
                  ),

                  const SizedBox(height: 16),

                  // 类别卡片网格
                  const CategoryCardGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 算法配置区域 - 水平布局
class _AlgorithmSection extends StatelessWidget {
  const _AlgorithmSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度决定布局方式
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          // 宽屏: 左右布局
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧: 算法配置卡片
              Expanded(
                flex: 3,
                child: AlgorithmConfigCard(),
              ),
              SizedBox(width: 16),
              // 右侧: 概率分布图表
              Expanded(
                flex: 2,
                child: ProbabilitySection(),
              ),
            ],
          );
        } else {
          // 窄屏: 上下布局
          return const Column(
            children: [
              AlgorithmConfigCard(),
              SizedBox(height: 16),
              ProbabilitySection(),
            ],
          );
        }
      },
    );
  }
}
