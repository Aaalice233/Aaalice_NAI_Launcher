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
import 'character_tooltip_content.dart';
import 'inline_character_card.dart';
import 'inline_character_editor.dart';
import 'inline_character_row.dart';

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
class InlineCharacterSection extends StatelessWidget {
  const InlineCharacterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CharacterWorkbenchSection(
      presentation: _CharacterSectionPresentation.sidebarList,
    );
  }
}

/// 经典布局中紧邻主提示词的角色编辑区。
class ClassicCharacterSection extends StatelessWidget {
  const ClassicCharacterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CharacterWorkbenchSection(
      presentation: _CharacterSectionPresentation.workspaceGrid,
    );
  }
}

enum _CharacterSectionPresentation { sidebarList, workspaceGrid }

/// 两种桌面布局共享的角色区壳层。
///
/// 布局只决定角色卡如何排布；模型可用性、折叠状态、添加入口、摘要和
/// 悬浮预览保持同一事实来源，避免经典布局再次出现空状态入口丢失。
class _CharacterWorkbenchSection extends ConsumerWidget {
  const _CharacterWorkbenchSection({required this.presentation});

  static const panel = GenerationWorkbenchPanel.characters;

  final _CharacterSectionPresentation presentation;

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

    final isWorkspace =
        presentation == _CharacterSectionPresentation.workspaceGrid;

    return CollapsibleImagePanel(
      key: Key(
        isWorkspace
            ? 'classic-character-secondary-menu'
            : 'character-secondary-menu',
      ),
      title: l10n.character_buttonLabel,
      icon: Icons.people,
      leading: _CharacterStackIcon(
        key: const Key('character-stack-icon'),
        characters: characters,
      ),
      isExpanded: isExpanded,
      onToggle: () => unawaited(
        ref.read(generationPanelExpansionProvider.notifier).toggle(panel),
      ),
      hasData: characters.isNotEmpty,
      headerActions: const [AddCharacterButtons(compact: true)],
      alignHeaderActionsAfterTitle: true,
      collapsedHoverPreviewBuilder: characters.isEmpty
          ? null
          : (context) => CharacterTooltipContent(config: config),
      childBuilder: (context) {
        if (!isWorkspace) {
          return _CharacterPanelContent(characters: characters);
        }
        if (characters.isEmpty) return const SizedBox.shrink();
        return const InlineCharacterRow(showAddAction: false, embedded: true);
      },
    );
  }
}

class _CharacterStackIcon extends StatelessWidget {
  const _CharacterStackIcon({super.key, required this.characters});

  static const _personSize = 20.0;
  static const _overlapOffset = 8.0;

  final List<CharacterPrompt> characters;

  Color _genderColor(CharacterGender gender) => switch (gender) {
    CharacterGender.female => const Color(0xFFEC4899),
    CharacterGender.male => const Color(0xFF3B82F6),
    CharacterGender.other => const Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (characters.isEmpty) {
      return Semantics(
        label: buildCharacterPanelSummary(
          AppLocalizations.of(context)!,
          characters,
        ),
        child: Icon(
          Icons.person_add_alt_1_outlined,
          size: _personSize,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final visibleCharacters = characters.take(3).toList(growable: false);
    final hiddenCount = characters.length - visibleCharacters.length;
    final peopleWidth =
        _personSize + (visibleCharacters.length - 1) * _overlapOffset;
    final totalWidth = peopleWidth + (hiddenCount > 0 ? 19 : 0);

    return Semantics(
      label: buildCharacterPanelSummary(
        AppLocalizations.of(context)!,
        characters,
      ),
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        width: totalWidth,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < visibleCharacters.length; index++)
              Positioned(
                key: ValueKey('character-stack-person-$index'),
                left: index * _overlapOffset,
                top: 2,
                child: Opacity(
                  opacity: visibleCharacters[index].enabled ? 1 : 0.38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        size: _personSize + 3,
                        color: colorScheme.surface,
                      ),
                      Icon(
                        Icons.person,
                        size: _personSize,
                        color: _genderColor(
                          visibleCharacters[index].effectiveGender,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hiddenCount > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  key: const Key('character-stack-overflow-count'),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 14,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '+$hiddenCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
        ],
      ),
    );
  }
}
