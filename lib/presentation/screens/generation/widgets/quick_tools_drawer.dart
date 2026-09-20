import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/character_position_canvas_provider.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../widgets/character/add_character_buttons.dart';
import '../../../widgets/character/mobile_character_manager_sheet.dart';
import '../../../widgets/common/themed_button.dart';
import '../../../widgets/common/themed_switch.dart';
import '../../../widgets/prompt/fixed_tag_edit_dialog.dart';
import '../../../widgets/prompt/fixed_tags_dialog.dart';

/// 生成页快捷工具抽屉（移动端左抽屉）。
///
/// 左侧抽屉承载高频的固定词 / 角色开关操作，可以一边看生成结果一边调整，
/// 替代会占满图像区的停靠面板。深度编辑（新建 / 改内容 / 连线）仍跳转完整界面。
///
/// 偏离上游：上游 v4.2.1 的移动端生成页没有这个抽屉，左 `drawer` 给了参数面板、
/// 右 `endDrawer` 给了历史；固定词在移动端只有
/// `mobile_generation_workspace.dart` 里那个只读计数 chip，没有任何逐条开关 UI。
/// 我们把左抽屉留给快捷工具、参数面板挪到 `endDrawer`、历史降级成顶栏按钮弹出的
/// `AdaptivePresenter.showPanel`（见 `mobile_generation_chrome.dart`）。
/// 同一个 Scaffold 只有这一组 slot，三块面板放不下，这是有意的取舍而非遗漏。
class GenerationQuickToolsDrawer extends ConsumerStatefulWidget {
  const GenerationQuickToolsDrawer({super.key});

  @override
  ConsumerState<GenerationQuickToolsDrawer> createState() =>
      _GenerationQuickToolsDrawerState();
}

class _GenerationQuickToolsDrawerState
    extends ConsumerState<GenerationQuickToolsDrawer> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 角色位置画布渲染在生成页预览区，也就是这个抽屉的背后。打开画布的开关只存在
    // 于抽屉里弹出的角色管理器内，不把抽屉收掉用户点完屏幕毫无变化。
    // 上游的 MobileCharacterManagerSheet 只负责收掉它自己那一层（pop 自身路由），
    // 抽屉这一层是我们加的，必须由我们自己收。
    ref.listen<bool>(characterPositionCanvasProvider, (previous, next) {
      if (!next || previous == true) return;
      Scaffold.maybeOf(context)?.closeDrawer();
    });

    return Drawer(
      key: const ValueKey('generation-quick-tools-drawer'),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: SegmentedButton<int>(
                key: const ValueKey('generation-quick-tools-tabs'),
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.push_pin_outlined, size: 16),
                    label: Text(context.l10n.fixedTags_label),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.people_outline, size: 16),
                    label: Text(context.l10n.character_buttonLabel),
                  ),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (selection) {
                  setState(() => _tabIndex = selection.first);
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _tabIndex == 0
                  ? const _FixedTagsQuickList()
                  : const _CharactersQuickList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 固定词快捷开关列表。
class _FixedTagsQuickList extends ConsumerWidget {
  const _FixedTagsQuickList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(fixedTagsNotifierProvider);
    final positives = state.positiveEntries.sortedByOrder();
    final negatives = state.negativeEntries.sortedByOrder();

    return Column(
      children: [
        Expanded(
          child: state.entries.isEmpty
              ? _EmptyHint(
                  icon: Icons.push_pin_outlined,
                  text: context.l10n.fixedTags_empty,
                )
              : ListView(
                  key: const ValueKey('generation-quick-tools-fixed-tags'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    if (positives.isNotEmpty) ...[
                      _GroupLabel(text: context.l10n.fixedTags_positiveTitle),
                      for (final entry in positives)
                        _FixedTagSwitchTile(entry: entry),
                    ],
                    if (negatives.isNotEmpty) ...[
                      _GroupLabel(text: context.l10n.fixedTags_negativeTitle),
                      for (final entry in negatives)
                        _FixedTagSwitchTile(entry: entry),
                    ],
                  ],
                ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ThemedButton(
              key: const ValueKey('generation-quick-tools-manage-fixed-tags'),
              onPressed: () => FixedTagsDialog.show(context),
              icon: const Icon(Icons.tune, size: 17),
              label: Text(context.l10n.fixedTags_manage),
              style: ThemedButtonStyle.outlined,
            ),
          ),
        ),
      ],
    );
  }
}

class _FixedTagSwitchTile extends ConsumerWidget {
  const _FixedTagSwitchTile({required this.entry});

  final FixedTagEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // 开关是抽屉的高频主操作：整行点击即切换；编辑走行尾铅笔按钮（低频）。
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(
        entry.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          decoration: entry.enabled ? null : TextDecoration.lineThrough,
          color: entry.enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: entry.content.isEmpty
          ? null
          : Text(
              entry.content.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.outline,
            tooltip: context.l10n.common_edit,
            onPressed: () async {
              // 上游的 FixedTagEditDialog.show 已经走 AdaptivePresenter，
              // 键盘避让与窄屏呈现由它负责；这里只管把结果写回。
              final result = await FixedTagEditDialog.show(
                context: context,
                entry: entry,
              );
              if (result == null) return;
              await ref
                  .read(fixedTagsNotifierProvider.notifier)
                  .updateEntry(result);
            },
          ),
          ThemedSwitch(
            value: entry.enabled,
            onChanged: (_) => ref
                .read(fixedTagsNotifierProvider.notifier)
                .toggleEnabled(entry.id),
            scale: 0.7,
          ),
        ],
      ),
      onTap: () =>
          ref.read(fixedTagsNotifierProvider.notifier).toggleEnabled(entry.id),
    );
  }
}

/// 角色快捷开关列表。
class _CharactersQuickList extends ConsumerStatefulWidget {
  const _CharactersQuickList();

  @override
  ConsumerState<_CharactersQuickList> createState() =>
      _CharactersQuickListState();
}

class _CharactersQuickListState extends ConsumerState<_CharactersQuickList> {
  static Color _genderColor(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return const Color(0xFFE91E63);
      case CharacterGender.male:
        return const Color(0xFF2196F3);
      case CharacterGender.other:
        return const Color(0xFF9E9E9E);
    }
  }

  static IconData _genderIcon(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return Icons.female;
      case CharacterGender.male:
        return Icons.male;
      case CharacterGender.other:
        return Icons.transgender;
    }
  }

  /// 深度编辑统一复用上游的移动端角色管理器。
  ///
  /// 偏离上游：上游只在提示词编辑区里通过
  /// `prompt_input_coordinator.showMobileCharacterManager()` 暴露这个面板，
  /// 抽屉这条入口是我们加的。ios-v2 自己维护过一份「单角色底部编辑抽屉 + 全屏
  /// 角色区块对话框」，在 v4.2.1 上与上游的管理器完全重复，这里不再重放，
  /// 只补上「从抽屉里带着选中角色进去」这一点。
  Future<void> _openCharacterManager({String? characterId}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(selectedCharacterIdProvider.notifier).select(characterId);
    await AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.prompt_characterPrompts,
      dialogWidth: 560,
      builder: (_, scrollController) =>
          MobileCharacterManagerSheet(scrollController: scrollController),
    );
    if (!mounted) return;
    ref.read(selectedCharacterIdProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final characters = ref.watch(characterPromptNotifierProvider).characters;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AddCharacterButtons(),
          ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        Expanded(
          child: characters.isEmpty
              ? _EmptyHint(
                  icon: Icons.people_outline,
                  text: context.l10n.character_summaryEmpty,
                )
              : ListView.builder(
                  key: const ValueKey('generation-quick-tools-characters'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: characters.length,
                  itemBuilder: (context, index) {
                    final character = characters[index];
                    void toggle() => ref
                        .read(characterPromptNotifierProvider.notifier)
                        .toggleCharacterEnabled(character.id);

                    // 与固定词一致：整行点击切换开关，行尾铅笔进编辑。
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.only(left: 16, right: 4),
                      leading: Icon(
                        _genderIcon(character.gender),
                        size: 20,
                        color: _genderColor(
                          character.gender,
                        ).withValues(alpha: character.enabled ? 1.0 : 0.4),
                      ),
                      title: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: character.enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      subtitle: character.prompt.isEmpty
                          ? null
                          : Text(
                              character.prompt.replaceAll('\n', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                            color: theme.colorScheme.outline,
                            tooltip: context.l10n.common_edit,
                            onPressed: () => _openCharacterManager(
                              characterId: character.id,
                            ),
                          ),
                          ThemedSwitch(
                            value: character.enabled,
                            onChanged: (_) => toggle(),
                            scale: 0.7,
                          ),
                        ],
                      ),
                      onTap: toggle,
                    );
                  },
                ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ThemedButton(
              key: const ValueKey('generation-quick-tools-manage-characters'),
              onPressed: () => _openCharacterManager(),
              icon: const Icon(Icons.dashboard_customize_outlined, size: 17),
              label: Text(context.l10n.prompt_characterPrompts),
              style: ThemedButtonStyle.outlined,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
