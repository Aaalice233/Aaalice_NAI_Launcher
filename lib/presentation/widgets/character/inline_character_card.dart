import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_position_canvas_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../common/decoded_memory_image.dart';
import 'add_to_library_dialog.dart';
import 'inline_character_editor.dart';

/// 内联角色卡（内容常显，点击即编辑）
///
/// 官网式设计：没有折叠态，只有「只读预览」和「正在编辑」两种状态。
/// - 未选中：头部条 + 提示词只读预览，点击任意处进入编辑
/// - 编辑中（[inlineEditor] 为 true）：头部条 + 原位编辑器
/// - 编辑中（[inlineEditor] 为 false，经典布局横排）：仅高亮边框，
///   编辑器由外部的全宽面板承载，保持网格排版整齐
/// - 词库角色的缩略图作为头部条背景横向铺满
/// - 编辑态点击卡片外部自动退回未选中状态
///
/// [compact] 用于经典布局的横排行：更矮的头部、更少的预览行数、
/// 头部只保留启用与删除按钮。
class InlineCharacterCard extends ConsumerStatefulWidget {
  final CharacterPrompt character;
  final int index;
  final int total;
  final bool compact;
  final bool inlineEditor;
  final bool showSelectionBorder;

  const InlineCharacterCard({
    super.key,
    required this.character,
    required this.index,
    required this.total,
    this.compact = false,
    this.inlineEditor = true,
    this.showSelectionBorder = true,
  });

  @override
  ConsumerState<InlineCharacterCard> createState() =>
      _InlineCharacterCardState();
}

class _InlineCharacterCardState extends ConsumerState<InlineCharacterCard> {
  /// 选中切换的统一动画规格（与左栏参数抽屉的节奏一致）
  static const _animDuration = Duration(milliseconds: 180);
  static const _animCurve = Curves.easeOutCubic;

  /// 卡的焦点父节点：hasFocus 含后代（输入框）焦点，
  /// 用于区分「点击外部失焦」与「点击自动补全浮层但焦点仍在输入框」
  final FocusNode _cardFocusNode = FocusNode(
    skipTraversal: true,
    canRequestFocus: false,
  );

  /// 模态对话框（位置/重命名/词库）打开期间抑制点外部收起
  bool _modalOpen = false;

  @override
  void dispose() {
    _cardFocusNode.dispose();
    super.dispose();
  }

  bool get _isEditing =>
      ref.watch(selectedCharacterIdProvider) == widget.character.id;

  CharacterPromptNotifier get _notifier =>
      ref.read(characterPromptNotifierProvider.notifier);

  void _enterEditing() {
    ref.read(selectedCharacterIdProvider.notifier).select(widget.character.id);
  }

  void _toggleEditing() {
    final selector = ref.read(selectedCharacterIdProvider.notifier);
    if (ref.read(selectedCharacterIdProvider) == widget.character.id) {
      selector.clear();
    } else {
      _enterEditing();
    }
  }

  /// 直接删除（不弹确认框）
  void _deleteCharacter() {
    final selector = ref.read(selectedCharacterIdProvider.notifier);
    if (ref.read(selectedCharacterIdProvider) == widget.character.id) {
      selector.clear();
    }
    _notifier.removeCharacter(widget.character.id);
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
    // 经典布局下编辑器在外部全宽面板里，点面板不能算「卡外」，
    // 退出逻辑全权交给面板自己的 TapRegion
    if (!widget.inlineEditor) return;
    if (_modalOpen) return;
    // 对话框属于独立 Route，点击其中的执行按钮也会被底层 TapRegion
    // 视为卡外点击；此时卸载编辑器会连带取消正在启动的助手任务。
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    // 位置画布打开时，点画布拖锚点是位置编辑的一部分，不退出编辑态
    if (ref.read(characterPositionCanvasProvider)) return;
    // TapRegion 恒挂（结构稳定），非选中卡的外部点击直接忽略
    if (ref.read(selectedCharacterIdProvider) != widget.character.id) return;
    // TapRegion 回调发生在指针按下时，等本帧手势与焦点变化尘埃落定再判断
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null && !currentRoute.isCurrent) return;
      // 用户点了另一张卡：选中已切换，别把新选择清掉
      if (ref.read(selectedCharacterIdProvider) != widget.character.id) {
        return;
      }
      // 点击自动补全浮层的建议项时浮层在卡外，但输入框焦点保持，
      // 此时不应退出编辑
      if (_cardFocusNode.hasFocus) return;
      ref.read(selectedCharacterIdProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = _isEditing;
    final enabled = widget.character.enabled;
    final showInlineEditor = isEditing && widget.inlineEditor;
    final genderColor = _genderColor(widget.character.effectiveGender);

    // 性别色只承担识别与层级，不大面积染色；选中态仍统一使用主题主色。
    final card = AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          genderColor.withValues(alpha: isEditing ? 0.08 : 0.035),
          isEditing
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(10),
        border: isEditing && widget.showSelectionBorder
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, theme, showInlineEditor),
          // 预览 ↔ 编辑器：高度平滑生长 + 内容交叉淡化，替代瞬时替换
          AnimatedSize(
            duration: _animDuration,
            curve: _animCurve,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // AnimatedSwitcher 默认用居中 Stack 布局，子项会缩成内容宽，
              // 预览区点击热区随之变窄；强制占满卡宽让整个框内都可点中
              child: showInlineEditor
                  ? SizedBox(
                      key: const ValueKey('editor'),
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: CharacterPromptEditor(
                          character: widget.character,
                          compact: widget.compact,
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('preview'),
                      width: double.infinity,
                      child: _buildPreview(context, theme),
                    ),
            ),
          ),
        ],
      ),
    );

    // TapRegion/Focus 恒挂，保持子树结构稳定（条件包装会让 Element
    // 无法复用、整卡重建闪一帧）；是否响应由回调内部判断
    return AnimatedOpacity(
      duration: _animDuration,
      opacity: enabled ? 1.0 : 0.48,
      child: Focus(
        focusNode: _cardFocusNode,
        child: TapRegion(onTapOutside: (_) => _handleTapOutside(), child: card),
      ),
    );
  }

  // ==================== 头部条 ====================

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    bool editableName,
  ) {
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final character = widget.character;
    final hasThumbnail =
        character.thumbnailPath != null &&
        character.thumbnailPath!.isNotEmpty &&
        File(character.thumbnailPath!).existsSync();
    final gender = character.effectiveGender;
    final genderColor = _genderColor(gender);
    final headerHeight = widget.compact ? 36.0 : 42.0;
    // 缩略图铺满头部时文字压图，统一转白色
    final onHeader = hasThumbnail ? Colors.white : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasThumbnail)
            _HeaderThumbnail(path: character.thumbnailPath!)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    genderColor.withValues(alpha: 0.13),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleEditing,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _GenderBadge(
                      gender: gender,
                      color: genderColor,
                      onImage: hasThumbnail,
                      compact: widget.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final nameStyle = theme.textTheme.labelMedium
                              ?.copyWith(
                                color: hasThumbnail
                                    ? Colors.white
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                shadows: hasThumbnail
                                    ? const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              );
                          // 编辑态名字就地可改，无需弹窗
                          if (editableName) {
                            return CharacterNameField(
                              key: ValueKey('name-${character.id}'),
                              character: character,
                              style: nameStyle,
                            );
                          }
                          return Text(
                            character.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle,
                          );
                        },
                      ),
                    ),
                    _HeaderIconButton(
                      icon: character.enabled
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: character.enabled
                          ? (hasThumbnail ? Colors.white : colorScheme.primary)
                          : onHeader,
                      tooltip: l10n.characterEditor_enabled,
                      onTap: () =>
                          _notifier.toggleCharacterEnabled(character.id),
                    ),
                    _CharacterActionsMenu(
                      onHeader: onHeader,
                      canMoveUp: widget.index > 0,
                      canMoveDown: widget.index < widget.total - 1,
                      onSelected: (action) => _handleAction(context, action),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, _CharacterCardAction action) {
    switch (action) {
      case _CharacterCardAction.moveUp:
        _notifier.moveCharacterUp(widget.index);
      case _CharacterCardAction.moveDown:
        _notifier.moveCharacterDown(widget.index);
      case _CharacterCardAction.addToLibrary:
        _openModal(
          () => AddToLibraryDialog.show(
            context,
            name: widget.character.name,
            content: CharacterPromptBlockParser.compose(
              positivePrompt: widget.character.prompt,
              negativePrompt: widget.character.negativePrompt,
            ),
          ),
        );
      case _CharacterCardAction.delete:
        _deleteCharacter();
    }
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

  // ==================== 只读预览 ====================

  Widget _buildPreview(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final prompt = widget.character.prompt;
    final isEmpty = prompt.trim().isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // 与头部一致的开关语义：未选中点击进入编辑，已选中（经典布局
        // 编辑器在外部面板、预览区仍可见）再点收起
        onTap: _toggleEditing,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            isEmpty ? l10n.characterEditor_promptHint : prompt,
            maxLines: widget.compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isEmpty
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

enum _CharacterCardAction { moveUp, moveDown, addToLibrary, delete }

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({
    required this.gender,
    required this.color,
    required this.onImage,
    required this.compact,
  });

  final CharacterGender gender;
  final Color color;
  final bool onImage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final icon = switch (gender) {
      CharacterGender.female => Icons.female,
      CharacterGender.male => Icons.male,
      CharacterGender.other => Icons.transgender,
    };
    final label = switch (gender) {
      CharacterGender.female => l10n.characterEditor_genderFemale,
      CharacterGender.male => l10n.characterEditor_genderMale,
      CharacterGender.other => l10n.characterEditor_genderOther,
    };

    final badge = Container(
      key: ValueKey('character-gender-${gender.name}'),
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: 3),
      decoration: BoxDecoration(
        color: onImage
            ? Colors.black.withValues(alpha: 0.34)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );

    if (!compact) return badge;
    return Tooltip(message: label, child: badge);
  }
}

class _CharacterActionsMenu extends StatelessWidget {
  const _CharacterActionsMenu({
    required this.onHeader,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onSelected,
  });

  final Color onHeader;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<_CharacterCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopupMenuButton<_CharacterCardAction>(
      key: const Key('character-actions-menu'),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: 19, color: onHeader),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CharacterCardAction.moveUp,
          enabled: canMoveUp,
          child: _CharacterMenuLabel(
            icon: Icons.arrow_upward,
            label: l10n.characterEditor_moveUp,
          ),
        ),
        PopupMenuItem(
          value: _CharacterCardAction.moveDown,
          enabled: canMoveDown,
          child: _CharacterMenuLabel(
            icon: Icons.arrow_downward,
            label: l10n.characterEditor_moveDown,
          ),
        ),
        PopupMenuItem(
          value: _CharacterCardAction.addToLibrary,
          child: _CharacterMenuLabel(
            icon: Icons.library_add_outlined,
            label: l10n.tagLibrary_addToLibrary,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CharacterCardAction.delete,
          child: _CharacterMenuLabel(
            icon: Icons.delete_outline,
            label: l10n.common_delete,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _CharacterMenuLabel extends StatelessWidget {
  const _CharacterMenuLabel({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: foreground)),
      ],
    );
  }
}

/// 头部条缩略图背景（横向铺满 + 暗遮罩保证文字可读）
class _HeaderThumbnail extends StatelessWidget {
  final String path;

  const _HeaderThumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cacheWidth = DecodedMemoryImage.resolveCacheDimension(
          logicalSize: width.isFinite ? math.min(width, 720.0) : 720.0,
          constrainedSize: null,
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.4),
              cacheWidth: cacheWidth,
              errorBuilder: (context, error, stack) => ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
            ),
            const ColoredBox(color: Color(0x66000000)),
          ],
        );
      },
    );
  }
}

/// 头部条小图标按钮
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
