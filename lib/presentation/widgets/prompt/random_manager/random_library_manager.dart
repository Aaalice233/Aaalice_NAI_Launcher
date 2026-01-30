import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/localization_extension.dart';

import 'preset_selector_bar.dart';
import 'algorithm_config_card.dart';
import 'probability_chart.dart';
import 'category_card.dart';
import 'search_filter_bar.dart';
import 'keyboard_shortcuts.dart';
import 'preview_generator_panel.dart';
import 'random_manager_widgets.dart';

/// 随机词库管理器 - 仪表盘布局
///
/// 布局结构:
/// ┌─────────────────────────────────────────────────────────────┐
/// │                      Title Bar                               │
/// ├─────────────────────────────────────────────────────────────┤
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
class RandomLibraryManager extends ConsumerStatefulWidget {
  const RandomLibraryManager({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const RandomLibraryManager(),
    );
  }

  @override
  ConsumerState<RandomLibraryManager> createState() =>
      _RandomLibraryManagerState();
}

class _RandomLibraryManagerState extends ConsumerState<RandomLibraryManager> {
  // 搜索筛选状态
  SearchFilterState _filterState = const SearchFilterState();
  bool _showPreviewPanel = false;

  void _onFilterChanged(SearchFilterState state) {
    setState(() => _filterState = state);
  }

  void _togglePreviewPanel() {
    setState(() => _showPreviewPanel = !_showPreviewPanel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: RandomManagerShortcuts(
          onGeneratePreview: _togglePreviewPanel,
          onSearch: () {
            // Focus 到搜索框
          },
          child: Container(
            width: 1280,
            height: 820,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title Bar
                DialogTitleBar(
                  title: l10n.config_title,
                  onClose: () => Navigator.of(context).pop(),
                ),
                // 预设选择栏 - 独立于内容区，直接在对话框顶层
                const PresetSelectorBar(),
                // Dashboard Content
                Expanded(
                  child: Row(
                    children: [
                      // 主内容区
                      Expanded(
                        child: _DashboardContent(
                          filterState: _filterState,
                          onFilterChanged: _onFilterChanged,
                        ),
                      ),
                      // 侧边预览面板 (可选显示)
                      if (_showPreviewPanel)
                        Container(
                          width: 300,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color:
                                    colorScheme.outlineVariant.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // 预览面板标题
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.preview_outlined,
                                      size: 16,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '生成预览',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: _togglePreviewPanel,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 预览生成面板
                              const Expanded(
                                child: PreviewGeneratorPanel(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 仪表盘主体内容
class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.filterState,
    required this.onFilterChanged,
  });

  final SearchFilterState filterState;
  final ValueChanged<SearchFilterState> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 搜索筛选栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchFilterBar(
              onFilterChanged: onFilterChanged,
              initialState: filterState,
            ),
          ),

          // 可滚动内容区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
          // 宽屏: 左右布局 - 使用 ConstrainedBox 限制右侧高度
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: const Row(
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
                  child: SingleChildScrollView(
                    child: ProbabilitySection(),
                  ),
                ),
              ],
            ),
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
