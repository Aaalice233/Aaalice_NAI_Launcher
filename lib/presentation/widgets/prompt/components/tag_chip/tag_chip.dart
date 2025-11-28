import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/common/app_toast.dart';

import '../../../../../data/models/prompt/prompt_tag.dart';
import '../../../../../data/services/tag_translation_service.dart';
import '../../core/prompt_tag_colors.dart';
import '../../core/prompt_tag_config.dart';
import '../tag_action_menu/bottom_action_sheet.dart';
import '../tag_action_menu/floating_action_menu.dart';
import 'tag_chip_edit_mode.dart';

/// 重构后的标签卡片组件
/// 支持悬浮自动显示菜单、双击内联编辑、权重括号显示
class TagChip extends ConsumerStatefulWidget {
  /// 标签数据
  final PromptTag tag;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 点击回调（切换选中）
  final VoidCallback? onTap;

  /// 双击回调（进入编辑）
  final VoidCallback? onDoubleTap;

  /// 切换启用回调
  final VoidCallback? onToggleEnabled;

  /// 权重变化回调
  final ValueChanged<double>? onWeightChanged;

  /// 文本变化回调
  final ValueChanged<String>? onTextChanged;

  /// 是否正在拖拽
  final bool isDragging;

  /// 是否显示控制（悬浮菜单等）
  final bool showControls;

  /// 是否紧凑模式
  final bool compact;

  /// 是否正在编辑
  final bool isEditing;

  /// 进入编辑模式回调
  final VoidCallback? onEnterEdit;

  /// 退出编辑模式回调
  final VoidCallback? onExitEdit;

  const TagChip({
    super.key,
    required this.tag,
    this.onDelete,
    this.onTap,
    this.onDoubleTap,
    this.onToggleEnabled,
    this.onWeightChanged,
    this.onTextChanged,
    this.isDragging = false,
    this.showControls = true,
    this.compact = false,
    this.isEditing = false,
    this.onEnterEdit,
    this.onExitEdit,
  });

  @override
  ConsumerState<TagChip> createState() => _TagChipState();

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}

class _TagChipState extends ConsumerState<TagChip>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _showMenu = false;
  String? _translation;
  Timer? _menuShowTimer;
  Timer? _menuHideTimer;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fetchTranslation();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(TagChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag.text != widget.tag.text ||
        oldWidget.tag.translation != widget.tag.translation) {
      _fetchTranslation();
    }

    if (oldWidget.isDragging != widget.isDragging) {
      if (widget.isDragging) {
        _scaleController.animateTo(1.0);
      }
    }
  }

  @override
  void dispose() {
    _menuShowTimer?.cancel();
    _menuHideTimer?.cancel();
    _scaleController.dispose();
    super.dispose();
  }

  void _fetchTranslation() {
    if (widget.tag.translation != null) {
      _translation = widget.tag.translation;
      return;
    }
    final translationService = ref.read(tagTranslationServiceProvider);
    _translation = translationService.translate(
      widget.tag.text,
      isCharacter: widget.tag.category == 4,
    );
    if (mounted) setState(() {});
  }

  void _onMouseEnter() {
    setState(() => _isHovering = true);
    _scaleController.forward();

    if (!TagChip.isMobile && widget.showControls) {
      _menuHideTimer?.cancel();
      _menuShowTimer = Timer(
        const Duration(milliseconds: 100),
        () {
          if (mounted && _isHovering) {
            setState(() => _showMenu = true);
          }
        },
      );
    }
  }

  void _onMouseExit() {
    setState(() => _isHovering = false);
    _scaleController.reverse();

    _menuShowTimer?.cancel();
    // 立即隐藏菜单，避免多个菜单同时显示
    _menuHideTimer = Timer(
      const Duration(milliseconds: 50),
      () {
        if (mounted && !_isHovering) {
          setState(() => _showMenu = false);
        }
      },
    );
  }

  void _onLongPress() {
    if (TagChip.isMobile) {
      _showMobileActionSheet();
    }
  }

  void _showMobileActionSheet() {
    TagBottomActionSheet.show(
      context,
      tag: widget.tag,
      onWeightChanged: widget.onWeightChanged,
      onToggleEnabled: widget.onToggleEnabled,
      onEdit: widget.onTextChanged != null ? _enterEditMode : null,
      onDelete: widget.onDelete,
      onCopy: () {
        Clipboard.setData(ClipboardData(text: widget.tag.toSyntaxString()));
        AppToast.success(context, '已复制到剪贴板');
      },
    );
  }

  void _enterEditMode() {
    widget.onEnterEdit?.call();
  }

  void _exitEditMode() {
    widget.onExitEdit?.call();
  }

  void _handleTextChanged(String newText) {
    widget.onTextChanged?.call(newText);
    _exitEditMode();
  }

  void _handleDoubleTap() {
    if (widget.onDoubleTap != null) {
      widget.onDoubleTap!();
    } else if (widget.onTextChanged != null) {
      // 默认双击进入编辑模式
      _enterEditMode();
    } else if (widget.onToggleEnabled != null) {
      // 如果没有编辑功能，则切换启用状态
      widget.onToggleEnabled!();
    }
  }

  /// 生成带权重语法的显示文本
  String get _displayText {
    final name = widget.tag.displayName;
    final layers = widget.tag.bracketLayers;

    if (layers > 0) {
      return '${'{' * layers}$name${'}' * layers}';
    } else if (layers < 0) {
      return '${'[' * (-layers)}$name${']' * (-layers)}';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    // 如果处于编辑模式，显示编辑组件
    if (widget.isEditing) {
      return _buildEditMode();
    }

    return _buildNormalMode();
  }

  Widget _buildEditMode() {
    final tagColor = PromptTagColors.getByCategory(widget.tag.category);

    return TagChipEditMode(
      initialText: widget.tag.text,
      onTextChanged: _handleTextChanged,
      onEditComplete: _exitEditMode,
      onEditCancel: _exitEditMode,
      compact: widget.compact,
      backgroundColor: tagColor.withOpacity(0.12),
      borderColor: tagColor,
    );
  }

  Widget _buildNormalMode() {
    final theme = Theme.of(context);
    final tagColor = PromptTagColors.getByCategory(widget.tag.category);
    final isEnabled = widget.tag.enabled;
    final isSelected = widget.tag.selected;

    // 检测特殊标签类型颜色
    final specialColor = PromptTagColors.getSpecialTypeColor(widget.tag.text);
    final effectiveColor = specialColor ?? tagColor;

    // 标签芯片（包含文本和删除按钮）
    final tagChip = Container(
      padding: EdgeInsets.only(
        left: widget.compact
            ? TagChipSizes.compactHorizontalPadding
            : TagChipSizes.normalHorizontalPadding,
        right: (widget.onDelete != null && !widget.compact)
            ? 4
            : (widget.compact
                ? TagChipSizes.compactHorizontalPadding
                : TagChipSizes.normalHorizontalPadding),
        top: widget.compact
            ? TagChipSizes.compactVerticalPadding
            : TagChipSizes.normalVerticalPadding,
        bottom: widget.compact
            ? TagChipSizes.compactVerticalPadding
            : TagChipSizes.normalVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: PromptTagColors.getBackgroundColor(
          effectiveColor,
          isSelected: isSelected,
          isEnabled: isEnabled,
          theme: theme,
        ),
        borderRadius: BorderRadius.circular(
          widget.compact
              ? TagChipSizes.compactBorderRadius
              : TagChipSizes.normalBorderRadius,
        ),
        border: Border.all(
          color: PromptTagColors.getBorderColor(
            effectiveColor,
            isSelected: isSelected,
            isHovered: _isHovering,
            isEnabled: isEnabled,
            theme: theme,
          ),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: widget.isDragging
            ? [
                BoxShadow(
                  color: effectiveColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _displayText,
            style: TextStyle(
              fontSize: widget.compact
                  ? TagChipSizes.compactFontSize
                  : TagChipSizes.normalFontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: isEnabled
                  ? theme.colorScheme.onSurface.withOpacity(0.9)
                  : theme.colorScheme.onSurface.withOpacity(0.35),
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ),
          // 删除按钮（常驻显示，在标签内部）
          if (widget.onDelete != null && !widget.compact)
            GestureDetector(
              onTap: widget.onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
        ],
      ),
    );

    Widget chipContent = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isDragging ? 1.05 : _scaleAnimation.value,
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签芯片
          tagChip,
          // 翻译（在标签下方，始终占位）
          if (!widget.compact)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                _translation ?? ' ',
                style: TextStyle(
                  fontSize: TagChipSizes.normalTranslationFontSize,
                  height: 1.2,
                  color: isEnabled
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : theme.colorScheme.onSurface.withOpacity(0.25),
                ),
              ),
            ),
        ],
      ),
    );

    // 包装交互层
    chipContent = MouseRegion(
      onEnter: (_) => _onMouseEnter(),
      onExit: (_) => _onMouseExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: _handleDoubleTap,
        onLongPress: _onLongPress,
        child: chipContent,
      ),
    );

    // 桌面端添加悬浮菜单
    if (!TagChip.isMobile && widget.showControls) {
      chipContent = FloatingMenuPortal(
        showMenu: _showMenu,
        menuBuilder: (context) => MouseRegion(
          onEnter: (_) {
            _menuHideTimer?.cancel();
            setState(() {
              _isHovering = true;
              _showMenu = true;
            });
          },
          onExit: (_) => _onMouseExit(),
          child: FloatingActionMenu(
            tag: widget.tag,
            onWeightChanged: widget.onWeightChanged,
            onToggleEnabled: widget.onToggleEnabled,
            onEdit: widget.onTextChanged != null ? _enterEditMode : null,
            onDelete: widget.onDelete,
            onCopy: () {
              Clipboard.setData(
                ClipboardData(text: widget.tag.toSyntaxString()),
              );
              AppToast.success(context, '已复制到剪贴板');
            },
          ),
        ),
        child: chipContent,
      );
    }

    return chipContent;
  }
}

/// 可拖拽的标签卡片
class DraggableTagChip extends StatelessWidget {
  final PromptTag tag;
  final int index;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleEnabled;
  final ValueChanged<double>? onWeightChanged;
  final ValueChanged<String>? onTextChanged;
  final bool showControls;
  final bool compact;
  final bool isEditing;
  final VoidCallback? onEnterEdit;
  final VoidCallback? onExitEdit;

  const DraggableTagChip({
    super.key,
    required this.tag,
    required this.index,
    this.onDelete,
    this.onTap,
    this.onDoubleTap,
    this.onToggleEnabled,
    this.onWeightChanged,
    this.onTextChanged,
    this.showControls = true,
    this.compact = false,
    this.isEditing = false,
    this.onEnterEdit,
    this.onExitEdit,
  });

  @override
  Widget build(BuildContext context) {
    // 编辑模式下不允许拖拽
    if (isEditing) {
      return TagChip(
        tag: tag,
        onDelete: onDelete,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onToggleEnabled: onToggleEnabled,
        onWeightChanged: onWeightChanged,
        onTextChanged: onTextChanged,
        showControls: showControls,
        compact: compact,
        isEditing: isEditing,
        onEnterEdit: onEnterEdit,
        onExitEdit: onExitEdit,
      );
    }

    return LongPressDraggable<int>(
      data: index,
      delay: Duration(milliseconds: TagChip.isMobile ? 300 : 200),
      feedback: Material(
        color: Colors.transparent,
        child: TagChip(
          tag: tag,
          isDragging: true,
          showControls: false,
          compact: compact,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: TagChip(
          tag: tag,
          showControls: false,
          compact: compact,
        ),
      ),
      child: TagChip(
        tag: tag,
        onDelete: onDelete,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onToggleEnabled: onToggleEnabled,
        onWeightChanged: onWeightChanged,
        onTextChanged: onTextChanged,
        showControls: showControls,
        compact: compact,
        isEditing: isEditing,
        onEnterEdit: onEnterEdit,
        onExitEdit: onExitEdit,
      ),
    );
  }
}
