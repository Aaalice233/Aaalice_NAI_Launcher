import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/generation/generation_panel_expansion_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../common/collapsible_image_panel.dart';
import '../common/themed_divider.dart';
import 'add_character_buttons.dart';
import 'character_position_canvas.dart';
import 'inline_character_card.dart';
import 'inline_character_editor.dart';

/// 构建角色二级菜单的单行摘要。
///
/// 摘要只统计启用角色；没有可用名称时使用本地化序号，保证窄栏中仍可识别。
String buildCharacterPanelSummary(
  AppLocalizations l10n,
  List<CharacterPrompt> characters,
) {
  if (characters.isEmpty) return l10n.character_summaryEmpty;

  final enabled = characters.where((character) => character.enabled).toList();
  if (enabled.isEmpty) {
    return l10n.character_summaryAllDisabled(characters.length);
  }

  final first = enabled.first;
  final firstIndex = characters.indexWhere((item) => item.id == first.id);
  final name = first.name.trim().isEmpty
      ? l10n.character_number(firstIndex + 1)
      : first.name.trim();
  if (enabled.length == 1) {
    return l10n.character_summaryEnabled(1, name);
  }
  return l10n.character_summaryMore(enabled.length, name, enabled.length - 1);
}

/// 官网布局左栏的角色二级菜单。
///
/// 标题与反推等工作台面板复用同一壳层；角色业务状态始终由 Provider 持有，
/// 折叠只影响展示，不改变生成参数。
class InlineCharacterSection extends ConsumerWidget {
  const InlineCharacterSection({super.key});

  static const panel = GenerationWorkbenchPanel.characters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isV4Model = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => ImageModels.isV4Model(params.model),
      ),
    );
    if (!isV4Model) return const SizedBox.shrink();

    final config = ref.watch(characterPromptNotifierProvider);
    final characters = config.characters;
    final isExpanded = ref.watch(
      generationPanelExpansionProvider.select(
        (state) => state.isExpanded(panel),
      ),
    );

    return CollapsibleImagePanel(
      key: const Key('character-secondary-menu'),
      title: l10n.character_buttonLabel,
      icon: Icons.people,
      isExpanded: isExpanded,
      onToggle: () => unawaited(
        ref.read(generationPanelExpansionProvider.notifier).toggle(panel),
      ),
      hasData: characters.isNotEmpty,
      summary: Text(
        buildCharacterPanelSummary(l10n, characters),
        key: const Key('character-panel-summary'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      childBuilder: (context) => _CharacterPanelContent(characters: characters),
    );
  }
}

class _CharacterPanelContent extends ConsumerWidget {
  const _CharacterPanelContent({required this.characters});

  final List<CharacterPrompt> characters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasCharacters = characters.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ThemedDivider(),
          if (hasCharacters) ...[
            Row(
              children: [
                const Expanded(child: CharacterPositionModeSegments()),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('character-clear-all'),
                  onPressed: () => confirmClearAllCharacters(context, ref),
                  tooltip: l10n.characterEditor_clearAll,
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < characters.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InlineCharacterCard(
                key: ValueKey(characters[i].id),
                character: characters[i],
                index: i,
                total: characters.length,
              ),
            ),
          const AddCharacterButtons(),
        ],
      ),
    );
  }
}
