import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../tag_library/tag_library_picker_dialog.dart';
import 'add_to_library_dialog.dart';
import 'inline_character_card.dart';
import 'inline_character_editor.dart';

/// 内联角色行（经典布局用，横排）
///
/// 位于提示词横条正下方，与主提示词同屏相邻：
/// - 角色卡固定宽度横排（Wrap 换行），网格始终整齐
/// - 选中的角色在网格下方展开全宽编辑面板，不打乱卡片排版
/// - 行尾「+」按钮弹出添加菜单（女/男/其他/词库）
/// - 无角色或非 V4 模型时整行隐藏，零高度成本
///
/// 全屏编辑与非全屏共用此组件，始终紧贴提示词区下方。
class InlineCharacterRow extends ConsumerWidget {
  const InlineCharacterRow({super.key});

  static const double _cardWidth = 190;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isV4Model = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => ImageModels.isV4Model(params.model),
      ),
    );
    if (!isV4Model) {
      return const SizedBox.shrink();
    }

    final characters = ref.watch(characterPromptNotifierProvider).characters;
    if (characters.isEmpty) {
      return const SizedBox.shrink();
    }

    final editingId = ref.watch(selectedCharacterIdProvider);
    CharacterPrompt? editingCharacter;
    var editingIndex = -1;
    for (var i = 0; i < characters.length; i++) {
      if (characters[i].id == editingId) {
        editingCharacter = characters[i];
        editingIndex = i;
        break;
      }
    }

    return Container(
      // 拉满可用宽度，确保顶部分隔线始终横贯整个工作区
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap 换行：角色多时排到第二排，不再横向滚动到不可见区域
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < characters.length; i++)
                SizedBox(
                  width: _cardWidth,
                  child: InlineCharacterCard(
                    key: ValueKey(characters[i].id),
                    character: characters[i],
                    index: i,
                    total: characters.length,
                    compact: true,
                    inlineEditor: false,
                  ),
                ),
              if (characters.length < 6) const _AddCharacterChip(),
            ],
          ),
          if (editingCharacter != null) ...[
            const SizedBox(height: 6),
            _RowEditorPanel(
              key: ValueKey('editor-${editingCharacter.id}'),
              character: editingCharacter,
              index: editingIndex,
              total: characters.length,
            ),
          ],
        ],
      ),
    );
  }
}

/// 全宽编辑面板（经典布局）
///
/// 网格下方展开：头部（名字 + 完整操作排 + 关闭）+ 提示词编辑器。
class _RowEditorPanel extends ConsumerStatefulWidget {
  final CharacterPrompt character;
  final int index;
  final int total;

  const _RowEditorPanel({
    super.key,
    required this.character,
    required this.index,
    required this.total,
  });

  @override
  ConsumerState<_RowEditorPanel> createState() => _RowEditorPanelState();
}

class _RowEditorPanelState extends ConsumerState<_RowEditorPanel> {
  /// hasFocus 含后代（输入框）焦点，见 InlineCharacterCard 的同名说明
  final FocusNode _panelFocusNode = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
  );

  bool _modalOpen = false;

  @override
  void dispose() {
    _panelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openModal(Future<void> Function() open) async {
    _modalOpen = true;
    try {
      await open();
    } finally {
      _modalOpen = false;
    }
  }

  void _handleTapOutside() {
    if (_modalOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(selectedCharacterIdProvider) != widget.character.id) {
        return;
      }
      if (_panelFocusNode.hasFocus) return;
      ref.read(selectedCharacterIdProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(characterPromptNotifierProvider.notifier);
    final iconColor = colorScheme.onSurfaceVariant;

    return TapRegion(
      onTapOutside: (_) => _handleTapOutside(),
      child: Focus(
        focusNode: _panelFocusNode,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _genderColor(widget.character.gender),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.character.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _PanelIconButton(
                    icon: Icons.arrow_upward,
                    color: iconColor,
                    tooltip: l10n.characterEditor_moveUp,
                    enabled: widget.index > 0,
                    onTap: () => notifier.moveCharacterUp(widget.index),
                  ),
                  _PanelIconButton(
                    icon: Icons.arrow_downward,
                    color: iconColor,
                    tooltip: l10n.characterEditor_moveDown,
                    enabled: widget.index < widget.total - 1,
                    onTap: () => notifier.moveCharacterDown(widget.index),
                  ),
                  _PanelIconButton(
                    icon: Icons.edit_outlined,
                    color: iconColor,
                    tooltip: l10n.characterEditor_name,
                    onTap: () => _openModal(
                      () => showCharacterRenameDialog(
                        context,
                        ref,
                        widget.character,
                      ),
                    ),
                  ),
                  _PanelIconButton(
                    icon: Icons.library_add_outlined,
                    color: iconColor,
                    tooltip: l10n.tagLibrary_addToLibrary,
                    onTap: () => _openModal(
                      () => AddToLibraryDialog.show(
                        context,
                        name: widget.character.name,
                        content: widget.character.prompt,
                      ),
                    ),
                  ),
                  _PanelIconButton(
                    icon: Icons.grid_on_rounded,
                    color: iconColor,
                    tooltip: l10n.characterEditor_position,
                    onTap: () => _openModal(
                      () => CharacterPositionDialog.show(
                        context,
                        widget.character.id,
                      ),
                    ),
                  ),
                  _PanelIconButton(
                    icon: Icons.close,
                    color: iconColor,
                    tooltip: l10n.characterEditor_close,
                    onTap: () =>
                        ref.read(selectedCharacterIdProvider.notifier).clear(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              CharacterPromptEditor(
                character: widget.character,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _genderColor(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899);
      case CharacterGender.male:
        return const Color(0xFF3B82F6);
      case CharacterGender.other:
        return const Color(0xFF8B5CF6);
    }
  }
}

/// 面板头部小图标按钮
class _PanelIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _PanelIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 15,
            color: enabled ? color : color.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// 行尾添加芯片（弹出 女/男/其他/词库 菜单）
class _AddCharacterChip extends ConsumerWidget {
  const _AddCharacterChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<CharacterGender?>(
      tooltip: l10n.character_addCharacter,
      padding: EdgeInsets.zero,
      onSelected: (gender) => _handleAdd(context, ref, gender),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CharacterGender.female,
          child: _menuRow(
            Icons.female,
            l10n.characterEditor_addFemale,
            const Color(0xFFEC4899),
          ),
        ),
        PopupMenuItem(
          value: CharacterGender.male,
          child: _menuRow(
            Icons.male,
            l10n.characterEditor_addMale,
            const Color(0xFF3B82F6),
          ),
        ),
        PopupMenuItem(
          value: CharacterGender.other,
          child: _menuRow(
            Icons.transgender,
            l10n.characterEditor_addOther,
            const Color(0xFF8B5CF6),
          ),
        ),
        PopupMenuItem(
          value: null,
          child: _menuRow(
            Icons.library_books_outlined,
            l10n.characterEditor_addFromLibrary,
            theme.colorScheme.tertiary,
          ),
        ),
      ],
      child: Container(
        width: 34,
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(
          Icons.add,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }

  Future<void> _handleAdd(
    BuildContext context,
    WidgetRef ref,
    CharacterGender? gender,
  ) async {
    final notifier = ref.read(characterPromptNotifierProvider.notifier);

    if (gender != null) {
      notifier.addCharacter(gender);
      _selectLast(ref);
      return;
    }

    // 词库导入
    final entry = await showDialog(
      context: context,
      builder: (context) => const TagLibraryPickerDialog(),
    );
    if (entry != null) {
      ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
      notifier.addCharacter(
        CharacterGender.female,
        name: entry.displayName,
        prompt: entry.content,
        thumbnailPath: entry.thumbnail,
      );
      _selectLast(ref);
    }
  }

  /// 新增后直接选中进入编辑，省一次点击
  void _selectLast(WidgetRef ref) {
    final characters = ref.read(characterPromptNotifierProvider).characters;
    if (characters.isNotEmpty) {
      ref
          .read(selectedCharacterIdProvider.notifier)
          .select(characters.last.id);
    }
  }
}
