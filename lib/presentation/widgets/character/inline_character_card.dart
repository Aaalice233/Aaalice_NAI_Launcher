import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const InlineCharacterCard({
    super.key,
    required this.character,
    required this.index,
    required this.total,
    this.compact = false,
    this.inlineEditor = true,
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
    // 位置画布打开时，点画布拖锚点是位置编辑的一部分，不退出编辑态
    if (ref.read(characterPositionCanvasProvider)) return;
    // TapRegion 恒挂（结构稳定），非选中卡的外部点击直接忽略
    if (ref.read(selectedCharacterIdProvider) != widget.character.id) return;
    // TapRegion 回调发生在指针按下时，等本帧手势与焦点变化尘埃落定再判断
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

    // 边框恒宽只变色：宽度变化会挤动内容造成微抖，颜色用动画过渡
    final card = AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEditing
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.3),
          width: 1.5,
        ),
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
    final headerHeight = widget.compact ? 30.0 : 34.0;
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
            ColoredBox(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleEditing,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (!hasThumbnail) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _genderColor(character.effectiveGender),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
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
                    // 操作全部平铺一排（两种布局一致：上移/下移/收藏词库），
                    // 名字用 Expanded 省略号吸收宽度，窄卡不会溢出
                    ..._buildFullActions(context, l10n, onHeader),
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
                    _HeaderIconButton(
                      icon: Icons.delete_outline,
                      color: hasThumbnail ? Colors.white : colorScheme.error,
                      tooltip: l10n.common_delete,
                      onTap: _deleteCharacter,
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

  List<Widget> _buildFullActions(
    BuildContext context,
    AppLocalizations l10n,
    Color onHeader,
  ) {
    return [
      _HeaderIconButton(
        icon: Icons.arrow_upward,
        color: onHeader,
        tooltip: l10n.characterEditor_moveUp,
        enabled: widget.index > 0,
        onTap: () => _notifier.moveCharacterUp(widget.index),
      ),
      _HeaderIconButton(
        icon: Icons.arrow_downward,
        color: onHeader,
        tooltip: l10n.characterEditor_moveDown,
        enabled: widget.index < widget.total - 1,
        onTap: () => _notifier.moveCharacterDown(widget.index),
      ),
      _HeaderIconButton(
        icon: Icons.library_add_outlined,
        color: onHeader,
        tooltip: l10n.tagLibrary_addToLibrary,
        onTap: () => _openModal(
          () => AddToLibraryDialog.show(
            context,
            name: widget.character.name,
            content: widget.character.prompt,
          ),
        ),
      ),
    ];
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
  final bool enabled;

  const _HeaderIconButton({
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
