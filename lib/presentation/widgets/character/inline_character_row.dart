import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_position_canvas_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../tag_library/tag_library_picker_dialog.dart';
import 'add_to_library_dialog.dart';
import 'character_position_canvas.dart';
import 'inline_character_card.dart';
import 'inline_character_editor.dart';

enum _CharacterAddAction {
  female(CharacterGender.female),
  male(CharacterGender.male),
  other(CharacterGender.other),
  library(null);

  const _CharacterAddAction(this.gender);

  final CharacterGender? gender;
}

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
          // 头部：位置模式分段 + 计数徽章 + 清空全部
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const CharacterPositionModeSegments(),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${characters.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: AppLocalizations.of(
                    context,
                  )!.characterEditor_clearAll,
                  waitDuration: const Duration(milliseconds: 500),
                  child: InkWell(
                    onTap: () => confirmClearAllCharacters(context, ref),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_sweep,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 等宽占满网格：每排卡片等分行宽（含尾部添加卡），排列整齐
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              final maxW = constraints.maxWidth;
              final itemCount = characters.length + 1;
              var columns = ((maxW + spacing) / (_cardWidth + spacing)).floor();
              columns = columns.clamp(1, itemCount);
              final cellWidth = (maxW - (columns - 1) * spacing) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var i = 0; i < characters.length; i++)
                    SizedBox(
                      width: cellWidth,
                      child: InlineCharacterCard(
                        key: ValueKey(characters[i].id),
                        character: characters[i],
                        index: i,
                        total: characters.length,
                        compact: true,
                        inlineEditor: false,
                      ),
                    ),
                  SizedBox(width: cellWidth, child: const _AddCharacterChip()),
                ],
              );
            },
          ),
          // 面板展开/收起用高度生长 + 交叉淡化，切换角色时两面板淡化过渡
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: editingCharacter == null
                  ? const SizedBox(width: double.infinity)
                  : SizedBox(
                      key: ValueKey('editor-${editingCharacter.id}'),
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _RowEditorPanel(
                          character: editingCharacter,
                          index: editingIndex,
                          total: characters.length,
                        ),
                      ),
                    ),
            ),
          ),
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
    // 位置画布打开时，点画布拖锚点是位置编辑的一部分，不退出编辑态
    if (ref.read(characterPositionCanvasProvider)) return;
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
                      color: _genderColor(widget.character.effectiveGender),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    // 面板即编辑态，名字就地可改
                    child: CharacterNameField(
                      key: ValueKey('panel-name-${widget.character.id}'),
                      character: widget.character,
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
                    icon: Icons.close,
                    color: iconColor,
                    tooltip: l10n.characterEditor_close,
                    onTap: () =>
                        ref.read(selectedCharacterIdProvider.notifier).clear(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              CharacterPromptEditor(character: widget.character, compact: true),
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
    final limitReached = ref.watch(characterLimitReachedProvider);

    if (limitReached) {
      // 官方上限（V5 为 32）已满：入口保留但禁用，悬浮说明原因。
      final limit = ref
          .read(characterPromptNotifierProvider.notifier)
          .characterLimit;
      return Tooltip(
        message: l10n.character_limitReached(limit.toString()),
        child: Opacity(
          opacity: 0.4,
          child: IgnorePointer(child: _buildChipBody(theme, l10n)),
        ),
      );
    }

    return PopupMenuButton<_CharacterAddAction>(
      key: const Key('character-add-menu'),
      tooltip: l10n.character_addCharacter,
      padding: EdgeInsets.zero,
      onSelected: (action) => _handleAdd(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CharacterAddAction.female,
          child: _menuRow(
            Icons.female,
            l10n.characterEditor_addFemale,
            const Color(0xFFEC4899),
          ),
        ),
        PopupMenuItem(
          value: _CharacterAddAction.male,
          child: _menuRow(
            Icons.male,
            l10n.characterEditor_addMale,
            const Color(0xFF3B82F6),
          ),
        ),
        PopupMenuItem(
          value: _CharacterAddAction.other,
          child: _menuRow(
            Icons.transgender,
            l10n.characterEditor_addOther,
            const Color(0xFF8B5CF6),
          ),
        ),
        PopupMenuItem(
          value: _CharacterAddAction.library,
          child: _menuRow(
            Icons.library_books_outlined,
            l10n.characterEditor_addFromLibrary,
            theme.colorScheme.tertiary,
          ),
        ),
      ],
      // 与角色卡同宽的添加卡（宽度由外部网格单元给定）
      child: _buildChipBody(theme, l10n),
    );
  }

  Widget _buildChipBody(ThemeData theme, AppLocalizations l10n) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.add,
          size: 18,
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
    _CharacterAddAction action,
  ) async {
    final notifier = ref.read(characterPromptNotifierProvider.notifier);
    final gender = action.gender;

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
      ref.read(selectedCharacterIdProvider.notifier).select(characters.last.id);
    }
  }
}
