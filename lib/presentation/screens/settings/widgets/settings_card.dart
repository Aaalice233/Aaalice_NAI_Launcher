import 'package:flutter/material.dart';

import '../../../themes/design_tokens.dart';

/// 设置卡片组件
///
/// 统一设置板块的卡片样式，支持标题、图标、右侧操作按钮和内容区。
class SettingsCard extends StatelessWidget {
  /// 标题文字（可选，为 null 时不显示标题栏）
  final String? title;

  /// 标题下方的可选说明。
  final String? description;

  /// 可选图标
  final IconData? icon;

  /// 可选卡片内分段导航，显示在标题栏上方。
  final Widget? navigation;

  /// 可选右侧操作按钮
  final Widget? trailing;

  /// 内容区
  final Widget child;

  /// 可选整卡点击行为，用于保留开关类设置的整行触控区域。
  final VoidCallback? onTap;

  /// 是否显示底部分隔线。仅在与后续内容存在真实结构边界时开启。
  final bool showDivider;

  const SettingsCard({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.navigation,
    this.trailing,
    required this.child,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 从页面基色直接抬高一层，避免未完整定义 Material 3
    // 容器色阶的主题落入带红色偏的默认 surfaceContainerLow。
    final cardColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.05),
      colorScheme.surface,
    );

    final description = this.description;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (navigation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingMd,
                  DesignTokens.spacingMd,
                  DesignTokens.spacingMd,
                  DesignTokens.spacingXxs,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: navigation!,
                ),
              ),
            if (title != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DesignTokens.spacingMd,
                  navigation == null
                      ? DesignTokens.spacingMd
                      : DesignTokens.spacingXs,
                  DesignTokens.spacingMd,
                  DesignTokens.spacingXs,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final titleBlock = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (icon != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              icon,
                              size: DesignTokens.iconSm,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: DesignTokens.spacingXs),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (description != null &&
                                  description.isNotEmpty) ...[
                                const SizedBox(height: DesignTokens.spacingXxs),
                                Text(
                                  description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                    if (trailing == null) return titleBlock;
                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleBlock,
                          const SizedBox(height: DesignTokens.spacingXs),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: trailing!,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: DesignTokens.spacingXs),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.45,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: trailing!,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Padding(
              padding: title != null
                  ? const EdgeInsets.fromLTRB(
                      DesignTokens.spacingSm,
                      DesignTokens.spacingXxs,
                      DesignTokens.spacingSm,
                      DesignTokens.spacingMd,
                    )
                  : const EdgeInsets.all(DesignTokens.spacingSm),
              child: child,
            ),
            if (showDivider)
              Divider(
                height: 1,
                indent: DesignTokens.spacingMd,
                endIndent: DesignTokens.spacingMd,
                color: theme.dividerColor,
              ),
          ],
        ),
      ),
    );
  }
}
