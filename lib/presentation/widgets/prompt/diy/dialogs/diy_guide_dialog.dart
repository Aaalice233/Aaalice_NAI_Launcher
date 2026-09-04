import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';

import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';

/// DIY 功能指南弹窗
///
/// 展示 DIY 系统的各项功能说明和使用示例
/// 采用 Dimensional Layering 设计风格
class DiyGuideDialog extends StatelessWidget {
  const DiyGuideDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.diyGuide_title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      width: 680,
      builder: (context, scrollController) =>
          DiyGuideDialog(scrollController: scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('diy-guide-scroll'),
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              Text(
                l10n.diyGuide_subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // 介绍文本
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.3),
                      colorScheme.primaryContainer.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.diyGuide_intro,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 功能指南卡片
              _GuideSection(
                title: l10n.diyGuide_hierarchyTitle,
                icon: Icons.account_tree_rounded,
                color: Colors.blue,
                description: l10n.diyGuide_hierarchyDescription,
                example: l10n.diyGuide_hierarchyExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_selectionModeTitle,
                icon: Icons.select_all_rounded,
                color: Colors.green,
                description: l10n.diyGuide_selectionModeDescription,
                example: l10n.diyGuide_selectionModeExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_weightTitle,
                icon: Icons.fitness_center_rounded,
                color: Colors.orange,
                description: l10n.diyGuide_weightDescription,
                example: l10n.diyGuide_weightExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_genderTitle,
                icon: Icons.wc_rounded,
                color: Colors.pink,
                description: l10n.diyGuide_genderDescription,
                example: l10n.diyGuide_genderExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_scopeTitle,
                icon: Icons.layers_rounded,
                color: Colors.purple,
                description: l10n.diyGuide_scopeDescription,
                example: l10n.diyGuide_scopeExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_conditionalTitle,
                icon: Icons.call_split_rounded,
                color: Colors.teal,
                description: l10n.diyGuide_conditionalDescription,
                example: l10n.diyGuide_conditionalExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_dependenciesTitle,
                icon: Icons.link_rounded,
                color: Colors.indigo,
                description: l10n.diyGuide_dependenciesDescription,
                example: l10n.diyGuide_dependenciesExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_visibilityTitle,
                icon: Icons.visibility_rounded,
                color: Colors.cyan,
                description: l10n.diyGuide_visibilityDescription,
                example: l10n.diyGuide_visibilityExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_timeTitle,
                icon: Icons.schedule_rounded,
                color: Colors.amber,
                description: l10n.diyGuide_timeDescription,
                example: l10n.diyGuide_timeExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_postProcessingTitle,
                icon: Icons.auto_fix_high_rounded,
                color: Colors.deepOrange,
                description: l10n.diyGuide_postProcessingDescription,
                example: l10n.diyGuide_postProcessingExample,
              ),
              _GuideSection(
                title: l10n.diyGuide_emphasisTitle,
                icon: Icons.format_bold_rounded,
                color: Colors.brown,
                description: l10n.diyGuide_emphasisDescription,
                example: l10n.diyGuide_emphasisExample,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(l10n.common_gotIt),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String example;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedCard(
        elevation: CardElevation.level1,
        hoverElevation: CardElevation.level2,
        enableHoverEffect: true,
        borderRadius: 12,
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(
            dividerColor: Colors.transparent,
            splashColor: color.withValues(alpha: 0.1),
            highlightColor: color.withValues(alpha: 0.05),
          ),
          child: Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ThemedDivider(),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // 示例代码框
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.l10n.diyGuide_exampleLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        example,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface.withValues(alpha: 0.9),
                          height: 1.5,
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
