import 'package:flutter/material.dart';

import '../../../themes/design_tokens.dart';

/// 统一设置页面的标题、说明、操作区与分组节奏。
///
/// 滚动、SafeArea 和最大内容宽度由 [SettingsScreen] 统一管理；此组件只负责
/// 页面内部的信息层级，不持有任何设置状态。
class SettingsPageLayout extends StatelessWidget {
  const SettingsPageLayout({
    super.key,
    required this.title,
    this.description,
    this.actions,
    required this.children,
  });

  final String title;
  final String? description;
  final Widget? actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = this.description;

    final headingContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            key: const ValueKey('settings-page-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.spacingXxs),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final heading = actions == null
        ? headingContent
        : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headingContent,
                    const SizedBox(height: DesignTokens.spacingSm),
                    actions!,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: headingContent),
                  const SizedBox(width: DesignTokens.spacingMd),
                  actions!,
                ],
              );
            },
          );

    return Semantics(
      container: true,
      child: Column(
        key: const ValueKey('settings-page-layout'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          if (children.isNotEmpty)
            const SizedBox(height: DesignTokens.spacingLg),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: DesignTokens.spacingMd),
            children[index],
          ],
        ],
      ),
    );
  }
}
