import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prompt/prompt_tag.dart';
import '../../../data/services/tag_translation_service.dart';
import 'weight_adjust_dialog.dart';

/// 标签分类颜色配置
class PromptTagColors {
  // 艺术家 - 珊瑚粉渐变
  static const artistGradient = [Color(0xFFFF6B6B), Color(0xFFFF8E8E)];
  static const artistBorder = Color(0xFFFF6B6B);

  // 角色 - 翠绿渐变
  static const characterGradient = [Color(0xFF4ECDC4), Color(0xFF6EE7DE)];
  static const characterBorder = Color(0xFF4ECDC4);

  // 版权 - 紫罗兰渐变
  static const copyrightGradient = [Color(0xFFA855F7), Color(0xFFC084FC)];
  static const copyrightBorder = Color(0xFFA855F7);

  // 通用 - 天蓝渐变
  static const generalGradient = [Color(0xFF60A5FA), Color(0xFF93C5FD)];
  static const generalBorder = Color(0xFF60A5FA);

  // 元数据 - 琥珀渐变
  static const metaGradient = [Color(0xFFFBBF24), Color(0xFFFCD34D)];
  static const metaBorder = Color(0xFFFBBF24);

  /// 根据分类获取渐变色
  static List<Color> getGradient(int category) {
    switch (category) {
      case 1:
        return artistGradient;
      case 3:
        return copyrightGradient;
      case 4:
        return characterGradient;
      case 5:
        return metaGradient;
      default:
        return generalGradient;
    }
  }

  /// 根据分类获取边框色
  static Color getBorder(int category) {
    switch (category) {
      case 1:
        return artistBorder;
      case 3:
        return copyrightBorder;
      case 4:
        return characterBorder;
      case 5:
        return metaBorder;
      default:
        return generalBorder;
    }
  }
}

/// 提示词标签卡片组件
/// 现代化设计：毛玻璃效果、渐变边框、权重光晕
class PromptTagChip extends ConsumerStatefulWidget {
  final PromptTag tag;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleEnabled;
  final ValueChanged<double>? onWeightChanged;
  final ValueChanged<String>? onTextChanged;
  final bool isDragging;
  final bool showWeightControls;
  final bool compact;

  const PromptTagChip({
    super.key,
    required this.tag,
    this.onDelete,
    this.onTap,
    this.onDoubleTap,
    this.onToggleEnabled,
    this.onWeightChanged,
    this.onTextChanged,
    this.isDragging = false,
    this.showWeightControls = true,
    this.compact = false,
  });

  @override
  ConsumerState<PromptTagChip> createState() => _PromptTagChipState();

  /// 是否为移动平台
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}

class _PromptTagChipState extends ConsumerState<PromptTagChip>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  String? _translation;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fetchTranslation();
  }

  @override
  void didUpdateWidget(PromptTagChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag.text != widget.tag.text) {
      _fetchTranslation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _fetchTranslation() {
    if (widget.tag.translation != null) {
      _translation = widget.tag.translation;
      return;
    }

    final translationService = ref.read(tagTranslationServiceProvider);
    final isCharacter = widget.tag.category == 4;
    _translation = translationService.translate(
      widget.tag.text,
      isCharacter: isCharacter,
    );
    if (mounted) setState(() {});
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.showWeightControls) return;
    if (event is PointerScrollEvent && _isHovering) {
      if (event.scrollDelta.dy < 0) {
        widget.onWeightChanged?.call(widget.tag.weight + PromptTag.weightStep);
        HapticFeedback.lightImpact();
      } else if (event.scrollDelta.dy > 0) {
        widget.onWeightChanged?.call(widget.tag.weight - PromptTag.weightStep);
        HapticFeedback.lightImpact();
      }
    }
  }

  void _showWeightDialog() {
    if (widget.onWeightChanged == null) return;

    WeightAdjustDialog.show(
      context,
      tag: widget.tag,
      onWeightChanged: widget.onWeightChanged!,
      onToggleEnabled: widget.onToggleEnabled,
      onDelete: widget.onDelete,
    );
  }

  void _showEditDialog() {
    if (widget.onTextChanged == null) return;

    TagEditDialog.show(
      context,
      tag: widget.tag,
      onTextChanged: widget.onTextChanged!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors = PromptTagColors.getGradient(widget.tag.category);
    final borderColor = PromptTagColors.getBorder(widget.tag.category);
    final isEnabled = widget.tag.enabled;
    final isSelected = widget.tag.selected;

    // 权重影响光晕强度
    final weightIntensity = ((widget.tag.weight - 1.0) / 0.5).clamp(0.0, 1.0);
    final glowOpacity = isEnabled ? (0.3 + weightIntensity * 0.4) : 0.0;

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          _animationController.forward();
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _animationController.reverse();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap ??
              (widget.onTextChanged != null ? _showEditDialog : null),
          onLongPress: PromptTagChip.isMobile && widget.showWeightControls
              ? _showWeightDialog
              : null,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isDragging ? 1.08 : _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  // 外发光效果
                  if (isEnabled && (widget.tag.weight > 1.0 || _isHovering))
                    BoxShadow(
                      color: borderColor.withOpacity(
                          glowOpacity * (0.5 + _glowAnimation.value * 0.3)),
                      blurRadius: 12 + (_glowAnimation.value * 4),
                      spreadRadius: -2,
                    ),
                  // 基础阴影
                  BoxShadow(
                    color: Colors.black.withOpacity(widget.isDragging ? 0.3 : 0.15),
                    blurRadius: widget.isDragging ? 12 : 6,
                    offset: Offset(0, widget.isDragging ? 4 : 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 10 : 12,
                      vertical: widget.compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      // 毛玻璃背景
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isEnabled
                            ? [
                                gradientColors[0].withOpacity(isSelected ? 0.35 : 0.2),
                                gradientColors[1].withOpacity(isSelected ? 0.25 : 0.12),
                              ]
                            : [
                                theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.3),
                                theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.2),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isEnabled
                            ? borderColor.withOpacity(
                                isSelected ? 0.9 : (_isHovering ? 0.7 : 0.4))
                            : theme.colorScheme.outline.withOpacity(0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 权重指示点
                        if (widget.tag.weight != 1.0 && !widget.compact)
                          _buildWeightDot(borderColor, isEnabled),

                        // 标签内容 - 固定两行高度保持一致
                        Flexible(
                          child: SizedBox(
                            height: widget.compact ? null : 34, // 固定高度
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 标签名
                                Text(
                                  widget.tag.displayName,
                                  style: TextStyle(
                                    fontSize: widget.compact ? 11 : 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                    color: isEnabled
                                        ? Colors.white.withOpacity(0.95)
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.4),
                                    decoration:
                                        isEnabled ? null : TextDecoration.lineThrough,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // 第二行：翻译或权重（始终占位）
                                if (!widget.compact)
                                  SizedBox(
                                    height: 14,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_translation != null)
                                          Flexible(
                                            child: Text(
                                              _translation!,
                                              style: TextStyle(
                                                fontSize: 10,
                                                height: 1.2,
                                                color: isEnabled
                                                    ? Colors.white.withOpacity(0.55)
                                                    : theme.colorScheme.onSurface
                                                        .withOpacity(0.3),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (_translation != null &&
                                            widget.tag.weight != 1.0)
                                          const SizedBox(width: 6),
                                        if (widget.tag.weight != 1.0)
                                          _buildWeightBadge(borderColor, isEnabled),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Hover 时的操作按钮
                        if (_isHovering &&
                            widget.showWeightControls &&
                            !widget.compact) ...[
                          const SizedBox(width: 6),
                          _buildHoverActions(theme, borderColor),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightDot(Color color, bool isEnabled) {
    final weight = widget.tag.weight;
    final dotSize = 6.0 + (weight - 1.0).abs() * 4;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: dotSize.clamp(6.0, 12.0),
        height: dotSize.clamp(6.0, 12.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? (weight > 1.0 ? const Color(0xFFFF9500) : const Color(0xFF007AFF))
              : Colors.grey.withOpacity(0.3),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: (weight > 1.0
                            ? const Color(0xFFFF9500)
                            : const Color(0xFF007AFF))
                        .withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildWeightBadge(Color color, bool isEnabled) {
    final weight = widget.tag.weight;
    final isPositive = weight > 1.0;
    final badgeColor = isPositive ? const Color(0xFFFF9500) : const Color(0xFF007AFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isEnabled ? badgeColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isEnabled ? badgeColor.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        widget.tag.weightDisplayText,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isEnabled ? badgeColor : Colors.grey,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildHoverActions(ThemeData theme, Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 减少权重
        _buildMiniButton(
          icon: Icons.remove,
          color: const Color(0xFF007AFF),
          onTap: () => widget.onWeightChanged
              ?.call(widget.tag.weight - PromptTag.weightStep),
        ),
        const SizedBox(width: 2),
        // 增加权重
        _buildMiniButton(
          icon: Icons.add,
          color: const Color(0xFFFF9500),
          onTap: () => widget.onWeightChanged
              ?.call(widget.tag.weight + PromptTag.weightStep),
        ),
        if (widget.onDelete != null) ...[
          const SizedBox(width: 4),
          _buildMiniButton(
            icon: Icons.close,
            color: const Color(0xFFFF3B30),
            onTap: widget.onDelete,
          ),
        ],
      ],
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3), width: 0.5),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
      ),
    );
  }
}

/// 可拖拽的标签卡片
class DraggablePromptTagChip extends StatelessWidget {
  final PromptTag tag;
  final int index;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<double>? onWeightChanged;
  final ValueChanged<String>? onTextChanged;
  final bool showWeightControls;

  const DraggablePromptTagChip({
    super.key,
    required this.tag,
    required this.index,
    this.onDelete,
    this.onTap,
    this.onDoubleTap,
    this.onWeightChanged,
    this.onTextChanged,
    this.showWeightControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<int>(
      data: index,
      delay: Duration(milliseconds: PromptTagChip.isMobile ? 300 : 200),
      feedback: Material(
        color: Colors.transparent,
        child: PromptTagChip(
          tag: tag,
          isDragging: true,
          showWeightControls: false,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: PromptTagChip(
          tag: tag,
          showWeightControls: false,
        ),
      ),
      child: PromptTagChip(
        tag: tag,
        onDelete: onDelete,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onWeightChanged: onWeightChanged,
        onTextChanged: onTextChanged,
        showWeightControls: showWeightControls,
      ),
    );
  }
}
