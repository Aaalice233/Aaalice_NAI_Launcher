import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/themed_divider.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../../data/services/alias_resolver_service.dart';

/// 多人角色悬浮提示内容组件
///
/// 显示当前多角色配置的详细信息，包括：
/// - 全局AI位置状态
/// - 所有角色列表（名称、性别、位置、提示词摘要）
/// - 统计摘要
///
/// Requirements: 5.3
class CharacterTooltipContent extends ConsumerWidget {
  final CharacterPromptConfig config;

  const CharacterTooltipContent({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (config.characters.isEmpty) {
      return _EmptyStateContent(l10n: l10n, colorScheme: colorScheme);
    }

    // 获取别名解析器，用于 UI 层动态解析
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);

    return _DetailedContent(
      config: config,
      aliasResolver: aliasResolver,
      l10n: l10n,
      theme: theme,
      colorScheme: colorScheme,
    );
  }
}

/// 空状态内容
class _EmptyStateContent extends StatelessWidget {
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _EmptyStateContent({
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 32,
            color: colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.characterTooltip_noCharacters,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.characterTooltip_clickToConfig,
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 详细内容
class _DetailedContent extends StatelessWidget {
  final CharacterPromptConfig config;
  final AliasResolverService aliasResolver;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _DetailedContent({
    required this.config,
    required this.aliasResolver,
    required this.l10n,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final enabledCount = config.characters.where((c) => c.enabled).length;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 360,
        maxHeight: 400,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 全局AI位置状态
          _GlobalAiStatusRow(
            globalAiChoice: config.globalAiChoice,
            l10n: l10n,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 10),

          // 角色列表
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < config.characters.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _CharacterItem(
                      character: config.characters[i],
                      globalAiChoice: config.globalAiChoice,
                      aliasResolver: aliasResolver,
                      l10n: l10n,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          // 底部分隔线
          const ThemedDivider(height: 1),
          const SizedBox(height: 8),

          // 统计摘要
          _SummaryRow(
            total: config.characters.length,
            enabled: enabledCount,
            l10n: l10n,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

/// 全局AI状态行
class _GlobalAiStatusRow extends StatelessWidget {
  final bool globalAiChoice;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _GlobalAiStatusRow({
    required this.globalAiChoice,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.characterTooltip_globalAiLabel,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            globalAiChoice ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: globalAiChoice ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            globalAiChoice
                ? l10n.characterTooltip_enabled
                : l10n.characterTooltip_disabled,
            style: TextStyle(
              color: globalAiChoice ? colorScheme.primary : colorScheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个角色项
class _CharacterItem extends StatelessWidget {
  final CharacterPrompt character;
  final bool globalAiChoice;
  final AliasResolverService aliasResolver;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _CharacterItem({
    required this.character,
    required this.globalAiChoice,
    required this.aliasResolver,
    required this.l10n,
    required this.theme,
    required this.colorScheme,
  });

  /// 根据性别获取颜色
  Color _getGenderColor() {
    switch (character.gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899); // 粉色
      case CharacterGender.male:
        return const Color(0xFF3B82F6); // 蓝色
      case CharacterGender.other:
        return const Color(0xFF8B5CF6); // 紫色
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = character.enabled;
    final genderColor = _getGenderColor();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            width: 3,
            color: isEnabled ? genderColor : colorScheme.outline,
          ),
        ),
      ),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称行
            Row(
              children: [
                // 状态圆点
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? genderColor : colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                // 角色名称
                Expanded(
                  child: Text(
                    character.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 性别标签
                _GenderBadge(
                  gender: character.gender,
                  l10n: l10n,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 6),
                // 位置标签
                _PositionBadge(
                  character: character,
                  globalAiChoice: globalAiChoice,
                  l10n: l10n,
                  colorScheme: colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 提示词摘要 - 解析别名
            _PromptSummary(
              prompt: aliasResolver.resolveAliases(character.prompt),
              negativePrompt:
                  aliasResolver.resolveAliases(character.negativePrompt),
              l10n: l10n,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

/// 性别标签
class _GenderBadge extends StatelessWidget {
  final CharacterGender gender;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _GenderBadge({
    required this.gender,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final text = switch (gender) {
      CharacterGender.female => l10n.characterEditor_genderFemale,
      CharacterGender.male => l10n.characterEditor_genderMale,
      CharacterGender.other => l10n.characterEditor_genderOther,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// 位置标签
class _PositionBadge extends StatelessWidget {
  final CharacterPrompt character;
  final bool globalAiChoice;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _PositionBadge({
    required this.character,
    required this.globalAiChoice,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (!character.enabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          l10n.characterTooltip_disabledLabel,
          style: TextStyle(
            color: colorScheme.outline,
            fontSize: 10,
          ),
        ),
      );
    }

    // 全局 AI 启用时显示 AI 标签
    if (globalAiChoice) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✨ ',
              style: TextStyle(fontSize: 10),
            ),
            Text(
              l10n.characterTooltip_positionAi,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 全局 AI 禁用时，显示自定义位置
    final positionText = character.customPosition?.toNaiString() ?? '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        positionText,
        style: TextStyle(
          color: colorScheme.onTertiaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 提示词摘要
class _PromptSummary extends StatelessWidget {
  final String prompt;
  final String negativePrompt;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _PromptSummary({
    required this.prompt,
    required this.negativePrompt,
    required this.l10n,
    required this.colorScheme,
  });

  String _truncate(String text, int maxLength) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 正向提示词
        _PromptLine(
          label: l10n.characterTooltip_promptLabel,
          content: prompt.isNotEmpty ? _truncate(prompt, 25) : null,
          notSetText: l10n.characterTooltip_notSet,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 2),
        // 负面提示词
        _PromptLine(
          label: l10n.characterTooltip_negativeLabel,
          content:
              negativePrompt.isNotEmpty ? _truncate(negativePrompt, 25) : null,
          notSetText: l10n.characterTooltip_notSet,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

/// 提示词行
class _PromptLine extends StatelessWidget {
  final String label;
  final String? content;
  final String notSetText;
  final ColorScheme colorScheme;

  const _PromptLine({
    required this.label,
    required this.content,
    required this.notSetText,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: colorScheme.outline,
            fontSize: 11,
          ),
        ),
        Expanded(
          child: Text(
            content != null ? '"$content"' : notSetText,
            style: TextStyle(
              color: content != null
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.outline,
              fontSize: 11,
              fontStyle: content != null ? FontStyle.normal : FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 统计摘要行
class _SummaryRow extends StatelessWidget {
  final int total;
  final int enabled;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _SummaryRow({
    required this.total,
    required this.enabled,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.characterTooltip_summary(total, enabled),
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.touch_app,
              size: 12,
              color: colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.characterTooltip_viewFullConfig,
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
