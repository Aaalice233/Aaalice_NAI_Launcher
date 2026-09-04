import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/character_position_canvas_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../tag_library/tag_library_picker_dialog.dart';
import 'add_to_library_dialog.dart';
import 'character_position_canvas.dart';
import 'inline_character_card.dart';
import 'inline_character_editor.dart';

class _InlineCharacterHeader extends ConsumerWidget {
  const _InlineCharacterHeader({
    required this.count,
    required this.compact,
    required this.forceExitMaximizedPrompt,
  });

  final int count;
  final bool compact;
  final bool forceExitMaximizedPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final controlExtent = context.interactionPolicy.minimumControlExtent;
    final modeOrTitle = count == 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.prompt_characterPrompts,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        : SingleChildScrollView(
            key: const ValueKey('character-position-mode-scroll'),
            scrollDirection: Axis.horizontal,
            child: CharacterPositionModeSegments(
              forceExitMaximizedPrompt: forceExitMaximizedPrompt,
            ),
          );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact || count == 0)
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        if (count > 0) ...[
          SizedBox(width: compact ? 4 : 8),
          TextButton.icon(
            key: const ValueKey('character-manager-clear-all'),
            onPressed: () => confirmClearAllCharacters(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(l10n.characterEditor_clearAll),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: Size(0, controlExtent),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );

    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 20;
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modeOrTitle,
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: modeOrTitle),
        const SizedBox(width: 8),
        actions,
      ],
    );
  }
}

enum _CharacterAddAction {
  female(CharacterGender.female),
  male(CharacterGender.male),
  other(CharacterGender.other),
  library(null);

  const _CharacterAddAction(this.gender);

  final CharacterGender? gender;
}

/// 移动端全屏角色管理器的卡片与编辑器主体。
///
/// 管理器使用单列卡片和全宽编辑器；角色状态仍由共享 Provider 持有，
/// 与桌面侧栏角色菜单保持一致。
class InlineCharacterRow extends ConsumerWidget {
  const InlineCharacterRow({
    super.key,
    this.showWhenEmpty = false,
    this.compactHeader = false,
    this.managerLayout = false,
  });

  /// Character managers need to keep the add entry visible before the first
  /// character exists; inline workspace rows retain their zero-height default.
  final bool showWhenEmpty;

  /// Omits the redundant count badge where phone width is better spent on the
  /// position controls and destructive action.
  final bool compactHeader;

  /// Phone managers use one full-width card per row so names and direct actions
  /// stay readable instead of becoming a dense desktop grid.
  final bool managerLayout;

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
    if (characters.isEmpty && !showWhenEmpty) {
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
      padding: managerLayout
          ? const EdgeInsets.fromLTRB(16, 12, 16, 6)
          : const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: managerLayout
          ? null
          : BoxDecoration(
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
          if (!managerLayout || characters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InlineCharacterHeader(
                count: characters.length,
                compact: compactHeader,
                forceExitMaximizedPrompt: managerLayout,
              ),
            ),
          // 等宽占满网格：每排卡片等分行宽（含尾部添加卡），排列整齐
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              final maxW = constraints.maxWidth;
              final itemCount = characters.length + 1;
              var columns = managerLayout
                  ? 1
                  : ((maxW + spacing) / (_cardWidth + spacing)).floor();
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
                        showSelectionBorder: !managerLayout,
                      ),
                    ),
                  SizedBox(
                    width: cellWidth,
                    child: _AddCharacterChip(showLabel: managerLayout),
                  ),
                ],
              );
            },
          ),
          // 面板展开/收起用高度生长 + 交叉淡化，切换角色时两面板淡化过渡
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
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
                          borderless: managerLayout,
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
  final bool borderless;

  const _RowEditorPanel({
    required this.character,
    required this.index,
    required this.total,
    required this.borderless,
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
    // 助手等子对话框位于独立 Route；点击其内容不能卸载底层编辑器，
    // 否则编辑器持有的流订阅会在任务启动时被取消。
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    // 位置画布打开时，点画布拖锚点是位置编辑的一部分，不退出编辑态
    if (ref.read(characterPositionCanvasProvider)) return;
    // 第一次点空白区域只收起软键盘并保留角色编辑器；没有输入焦点时
    // 再点外部区域才沿用原来的退出编辑行为。
    if (_panelFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null && !currentRoute.isCurrent) return;
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
    final largeText =
        widget.borderless && MediaQuery.textScalerOf(context).scale(14) >= 20;

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.borderless) ...[
          Text(
            l10n.characterEditor_editing,
            key: ValueKey('character-editor-context-${widget.character.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
        ],
        // 面板即编辑态，名字就地可改
        CharacterNameField(
          key: ValueKey('panel-name-${widget.character.id}'),
          character: widget.character,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final actions = <Widget>[
      _PanelIconButton(
        icon: Icons.arrow_upward,
        color: iconColor,
        tooltip: l10n.characterEditor_moveUp,
        enabled: widget.index > 0,
        comfortable: widget.borderless,
        onTap: () => notifier.moveCharacterUp(widget.index),
      ),
      _PanelIconButton(
        icon: Icons.arrow_downward,
        color: iconColor,
        tooltip: l10n.characterEditor_moveDown,
        enabled: widget.index < widget.total - 1,
        comfortable: widget.borderless,
        onTap: () => notifier.moveCharacterDown(widget.index),
      ),
      _PanelIconButton(
        icon: Icons.library_add_outlined,
        color: iconColor,
        tooltip: l10n.tagLibrary_addToLibrary,
        comfortable: widget.borderless,
        onTap: () => _openModal(
          () => AddToLibraryDialog.show(
            context,
            name: widget.character.name,
            content: CharacterPromptBlockParser.compose(
              positivePrompt: widget.character.prompt,
              negativePrompt: widget.character.negativePrompt,
            ),
          ),
        ),
      ),
      _PanelIconButton(
        icon: Icons.close,
        color: iconColor,
        tooltip: l10n.characterEditor_close,
        comfortable: widget.borderless,
        onTap: () => ref.read(selectedCharacterIdProvider.notifier).clear(),
      ),
    ];

    Widget buildIdentity() => Row(
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
        Expanded(child: nameBlock),
      ],
    );

    return TapRegion(
      groupId: CharacterPromptEditor.tapRegionGroupId(widget.character.id),
      onTapOutside: (_) => _handleTapOutside(),
      child: Focus(
        focusNode: _panelFocusNode,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          decoration: BoxDecoration(
            color: widget.borderless
                ? colorScheme.surfaceContainerLow
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(widget.borderless ? 12 : 8),
            border: widget.borderless
                ? null
                : Border.all(color: colorScheme.primary, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (largeText) ...[
                buildIdentity(),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ] else
                Row(
                  children: [
                    Expanded(child: buildIdentity()),
                    ...actions,
                  ],
                ),
              const SizedBox(height: 6),
              CharacterPromptEditor(
                character: widget.character,
                compact: !widget.borderless,
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
  final bool comfortable;

  const _PanelIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.comfortable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: comfortable ? 40 : 23,
          child: Icon(
            icon,
            size: comfortable ? 20 : 15,
            color: enabled ? color : color.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// 行尾添加芯片（弹出 女/男/其他/词库 菜单）
class _AddCharacterChip extends ConsumerWidget {
  const _AddCharacterChip({this.showLabel = false});

  final bool showLabel;

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
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                l10n.character_addCharacter,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
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
    final entry = await TagLibraryPickerDialog.show(context);
    if (entry != null) {
      final parsed = CharacterPromptBlockParser.parse(entry.content);
      ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
      notifier.addCharacter(
        CharacterGender.female,
        name: entry.displayName,
        prompt: parsed.positivePrompt,
        negativePrompt: parsed.hasNegativeBlock ? parsed.negativePrompt : null,
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
