import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../widgets/common/app_toast.dart';

import '../../../../../data/models/prompt/prompt_tag.dart';
import '../../../../../data/models/prompt/tag_favorite.dart';
import '../../../../../data/services/tag_translation_service.dart';
import '../../../../providers/tag_favorite_provider.dart';
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
    with TickerProviderStateMixin {
  bool _isHovering = false;
  bool _showMenu = false;
  String? _translation;
  Timer? _menuShowTimer;
  Timer? _menuHideTimer;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Weight animation
  late AnimationController _weightController;
  late Animation<double> _weightAnimation;
  double _currentWeight = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchTranslation();
    _currentWeight = widget.tag.weight;

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _weightController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _weightAnimation = Tween<double>(
      begin: _currentWeight,
      end: _currentWeight,
    ).animate(CurvedAnimation(
      parent: _weightController,
      curve: Curves.easeOut,
    ));

    _weightAnimation.addListener(() {
      setState(() {
        _currentWeight = _weightAnimation.value;
      });
    });
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

    // Animate weight changes
    if (oldWidget.tag.weight != widget.tag.weight) {
      _animateWeightChange(oldWidget.tag.weight, widget.tag.weight);
    }
  }

  @override
  void dispose() {
    _menuShowTimer?.cancel();
    _menuHideTimer?.cancel();
    _scaleController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Animate weight change from old value to new value
  void _animateWeightChange(double oldValue, double newValue) {
    _weightAnimation = Tween<double>(
      begin: oldValue,
      end: newValue,
    ).animate(CurvedAnimation(
      parent: _weightController,
      curve: Curves.easeOut,
    ));

    _weightController.forward(from: 0);
  }

  /// 切换收藏状态
  void _toggleFavorite() {
    final notifier = ref.read(tagFavoriteNotifierProvider.notifier);
    notifier.toggleFavorite(widget.tag);
  }

  /// 检查标签是否已收藏
  bool _isFavorite(List<TagFavorite> favorites) {
    return favorites.any((f) => f.tag.text == widget.tag.text);
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
        AppToast.success(context, context.l10n.tag_copiedToClipboard);
      },
      onToggleFavorite: _toggleFavorite,
      isFavorite: _isFavorite(ref.watch(tagFavoriteNotifierProvider).favorites),
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
    final weight = _currentWeight; // Use animated weight value
    final syntaxType = widget.tag.syntaxType;

    // 权重为 1.0 时，直接显示名称
    if ((weight - 1.0).abs() < 0.001) return name;

    // 根据语法类型选择显示格式
    switch (syntaxType) {
      case WeightSyntaxType.numeric:
        // 数值语法: 显示 weight::name::
        final weightStr = weight == weight.truncateToDouble()
            ? weight.toInt().toString()
            : weight
                .toStringAsFixed(2)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), '');
        return '$weightStr::$name::';

      case WeightSyntaxType.bracket:
      case WeightSyntaxType.none:
        // 括号语法: 显示 {{{name}}} 或 [[[name]]]
        final layers = widget.tag.bracketLayers;
        if (layers > 0) {
          return '${'{' * layers}$name${'}' * layers}';
        } else if (layers < 0) {
          return '${'[' * (-layers)}$name${']' * (-layers)}';
        }
        return name;
    }
  }

  /// 构建带语法高亮的文本组件
  Widget _buildSyntaxHighlightedText(ThemeData theme, Color effectiveColor, bool isEnabled) {
    final displayText = _displayText;
    final name = widget.tag.displayName;
    final weight = _currentWeight;
    final syntaxType = widget.tag.syntaxType;

    // 权重为 1.0 时，直接显示名称（无语法高亮）
    if ((weight - 1.0).abs() < 0.001) {
      return Text(
        displayText,
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
      );
    }

    // 构建文本片段列表
    final List<TextSpan> spans = [];

    switch (syntaxType) {
      case WeightSyntaxType.numeric:
        // 数值语法: weight::name::
        final weightStr = weight == weight.truncateToDouble()
            ? weight.toInt().toString()
            : weight
                .toStringAsFixed(2)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), '');

        // 权重数字（等宽字体）
        spans.add(TextSpan(
          text: weightStr,
          style: TextStyle(
            fontSize: widget.compact
                ? TagChipSizes.compactFontSize
                : TagChipSizes.normalFontSize,
            fontWeight: FontWeight.w500,
            height: 1.2,
            fontFamily: 'monospace',
            color: isEnabled
                ? effectiveColor.withOpacity(0.9)
                : theme.colorScheme.onSurface.withOpacity(0.35),
            decoration: isEnabled ? null : TextDecoration.lineThrough,
          ),
        ));

        // 双冒号（括号颜色）
        spans.add(TextSpan(
          text: '::',
          style: TextStyle(
            fontSize: widget.compact
                ? TagChipSizes.compactFontSize
                : TagChipSizes.normalFontSize,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: isEnabled
                ? effectiveColor.withOpacity(0.6)
                : theme.colorScheme.onSurface.withOpacity(0.2),
            decoration: isEnabled ? null : TextDecoration.lineThrough,
          ),
        ));

        // 标签名称
        spans.add(TextSpan(
          text: name,
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
        ));

        // 结尾双冒号（括号颜色）
        spans.add(TextSpan(
          text: '::',
          style: TextStyle(
            fontSize: widget.compact
                ? TagChipSizes.compactFontSize
                : TagChipSizes.normalFontSize,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: isEnabled
                ? effectiveColor.withOpacity(0.6)
                : theme.colorScheme.onSurface.withOpacity(0.2),
            decoration: isEnabled ? null : TextDecoration.lineThrough,
          ),
        ));
        break;

      case WeightSyntaxType.bracket:
      case WeightSyntaxType.none:
        // 括号语法: {{{name}}} 或 [[[name]]]
        final layers = widget.tag.bracketLayers;
        if (layers > 0) {
          // 开括号
          spans.add(TextSpan(
            text: '{' * layers,
            style: TextStyle(
              fontSize: widget.compact
                  ? TagChipSizes.compactFontSize
                  : TagChipSizes.normalFontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: isEnabled
                  ? effectiveColor.withOpacity(0.6)
                  : theme.colorScheme.onSurface.withOpacity(0.2),
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ));
        } else if (layers < 0) {
          // 开括号
          spans.add(TextSpan(
            text: '[' * (-layers),
            style: TextStyle(
              fontSize: widget.compact
                  ? TagChipSizes.compactFontSize
                  : TagChipSizes.normalFontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: isEnabled
                  ? effectiveColor.withOpacity(0.6)
                  : theme.colorScheme.onSurface.withOpacity(0.2),
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ));
        }

        // 标签名称
        spans.add(TextSpan(
          text: name,
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
        ));

        if (layers > 0) {
          // 闭括号
          spans.add(TextSpan(
            text: '}' * layers,
            style: TextStyle(
              fontSize: widget.compact
                  ? TagChipSizes.compactFontSize
                  : TagChipSizes.normalFontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: isEnabled
                  ? effectiveColor.withOpacity(0.6)
                  : theme.colorScheme.onSurface.withOpacity(0.2),
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ));
        } else if (layers < 0) {
          // 闭括号
          spans.add(TextSpan(
            text: ']' * (-layers),
            style: TextStyle(
              fontSize: widget.compact
                  ? TagChipSizes.compactFontSize
                  : TagChipSizes.normalFontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: isEnabled
                  ? effectiveColor.withOpacity(0.6)
                  : theme.colorScheme.onSurface.withOpacity(0.2),
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ));
        }
        break;
    }

    return Text.rich(
      TextSpan(children: spans),
    );
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
    final favorites = ref.watch(tagFavoriteNotifierProvider).favorites;
    final isDark = theme.brightness == Brightness.dark;

    // 检测特殊标签类型颜色
    final specialColor = PromptTagColors.getSpecialTypeColor(widget.tag.text);
    final effectiveColor = specialColor ?? tagColor;

    // 获取边框颜色
    final borderColor = PromptTagColors.getBorderColor(
      effectiveColor,
      isSelected: isSelected,
      isHovered: _isHovering,
      isEnabled: isEnabled,
      theme: theme,
    );

    // 计算阴影配置
    final shadowBlur = widget.isDragging
        ? TagShadowConfig.draggingBlurRadius
        : _isHovering
            ? TagShadowConfig.hoverBlurRadius
            : isSelected
                ? TagShadowConfig.selectedBlurRadius
                : isEnabled
                    ? TagShadowConfig.normalBlurRadius
                    : TagShadowConfig.disabledBlurRadius;

    final shadowOffset = widget.isDragging
        ? Offset(TagShadowConfig.draggingOffsetX, TagShadowConfig.draggingOffsetY)
        : _isHovering
            ? Offset(TagShadowConfig.hoverOffsetX, TagShadowConfig.hoverOffsetY)
            : isSelected
                ? Offset(TagShadowConfig.selectedOffsetX, TagShadowConfig.selectedOffsetY)
                : isEnabled
                    ? Offset(TagShadowConfig.normalOffsetX, TagShadowConfig.normalOffsetY)
                    : Offset(TagShadowConfig.disabledOffsetX, TagShadowConfig.disabledOffsetY);

    final shadowOpacity = widget.isDragging
        ? TagShadowConfig.draggingOpacity
        : _isHovering
            ? TagShadowConfig.hoverOpacity
            : isSelected
                ? TagShadowConfig.selectedOpacity
                : isEnabled
                    ? TagShadowConfig.normalOpacity
                    : TagShadowConfig.disabledOpacity;

    // 获取渐变色
    final gradient = isEnabled
        ? CategoryGradient.getThemedGradient(
            widget.tag.category,
            isDark: isDark,
          )
        : null;

    // 标签芯片（包含文本和删除按钮）- 使用 AnimatedContainer 实现平滑颜色过渡
    final tagChipContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
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
        gradient: gradient,
        color: isEnabled
            ? null
            : PromptTagColors.getBackgroundColor(
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
          color: borderColor,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSyntaxHighlightedText(theme, effectiveColor, isEnabled),
          // 收藏按钮（常驻显示，在标签内部）
          if (!widget.compact)
            _FavoriteButton(
              isFavorite: _isFavorite(favorites),
              onTap: _toggleFavorite,
              theme: theme,
            ),
          // 删除按钮（常驻显示，在标签内部）
          if (widget.onDelete != null && !widget.compact)
            _DeleteButton(
              onTap: widget.onDelete!,
              theme: theme,
            ),
        ],
      ),
    );

    // 拖拽时添加虚线边框
    final tagChipWithBorder = widget.isDragging
        ? _DashedBorder(
            color: borderColor,
            strokeWidth: 2,
            dashWidth: 4,
            dashSpace: 3,
            borderRadius: widget.compact
                ? TagChipSizes.compactBorderRadius
                : TagChipSizes.normalBorderRadius,
            child: tagChipContent,
          )
        : tagChipContent;

    // Apply brightness overlay on hover - 使用 200ms 实现平滑过渡
    final tagChip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      foregroundDecoration: BoxDecoration(
        color: _isHovering && !TagChip.isMobile
            ? Colors.white.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(
          widget.compact
              ? TagChipSizes.compactBorderRadius
              : TagChipSizes.normalBorderRadius,
        ),
      ),
      child: tagChipWithBorder,
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
                  fontStyle: FontStyle.italic,
                  color: isEnabled
                      ? theme.colorScheme.onSurface.withOpacity(0.4)
                      : theme.colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
            ),
        ],
      ),
    );

    // 包装交互层 - 添加 Material 以支持水波纹效果
    chipContent = Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => _onMouseEnter(),
        onExit: (_) => _onMouseExit(),
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: _handleDoubleTap,
          onLongPress: _onLongPress,
          splashColor: effectiveColor.withOpacity(0.2),
          highlightColor: effectiveColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(
            widget.compact
                ? TagChipSizes.compactBorderRadius
                : TagChipSizes.normalBorderRadius,
          ),
          child: chipContent,
        ),
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
              AppToast.success(context, context.l10n.tag_copiedToClipboard);
            },
          ),
        ),
        child: chipContent,
      );
    }

    // Wrap in RepaintBoundary to isolate animations and improve performance
    return RepaintBoundary(child: chipContent);
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
        child: RepaintBoundary(
          child: TagChip(
            tag: tag,
            isDragging: true,
            showControls: false,
            compact: compact,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: RepaintBoundary(
          child: TagChip(
            tag: tag,
            showControls: false,
            compact: compact,
          ),
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

/// 带 hover 效果的删除按钮
class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  final ThemeData theme;

  const _DeleteButton({
    required this.onTap,
    required this.theme,
  });

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _shrinkController;
  late Animation<double> _shrinkAnimation;

  @override
  void initState() {
    super.initState();
    _shrinkController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shrinkAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _shrinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shrinkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _shrinkController.forward().then((_) {
      widget.onTap();
      _shrinkController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.only(left: 6),
            child: AnimatedBuilder(
              animation: _shrinkAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _shrinkAnimation.value,
                  child: Opacity(
                    opacity: _shrinkAnimation.value,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _isHovering
                            ? widget.theme.colorScheme.error.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: _isHovering
                            ? widget.theme.colorScheme.error
                            : widget.theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的收藏按钮
class _FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final ThemeData theme;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;

  @override
  void initState() {
    super.initState();
    _jumpController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _jumpAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _jumpController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _jumpController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.only(left: 4),
            child: AnimatedBuilder(
              animation: _jumpAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _jumpAnimation.value,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _isHovering
                          ? (widget.isFavorite
                              ? Colors.red.withOpacity(0.15)
                              : widget.theme.colorScheme.primary.withOpacity(0.15))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 12,
                      color: widget.isFavorite
                          ? (_isHovering
                              ? Colors.red.shade400
                              : Colors.red.shade300)
                          : (_isHovering
                              ? widget.theme.colorScheme.primary
                              : widget.theme.colorScheme.onSurface.withOpacity(0.4)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 虚线边框组件
class _DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  const _DashedBorder({
    required this.child,
    required this.color,
    this.strokeWidth = 2,
    this.dashWidth = 4,
    this.dashSpace = 3,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// 虚线边框绘制器
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path, dashWidth, dashSpace);

    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dest = Path();
    for (final uiMetricPath in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;

      while (distance < uiMetricPath.length) {
        final double len = draw ? dashWidth : dashSpace;
        if (draw) {
          dest.addPath(
            uiMetricPath.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
