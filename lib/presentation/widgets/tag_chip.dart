import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/tag_translation_lookup.dart';

/// 简单标签芯片组件
///
/// 显示带颜色的标签，支持点击和自动翻译
/// 用于在线画廊、权重调整等简单场景
class SimpleTagChip extends ConsumerStatefulWidget {
  final String tag;
  final Color? color;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final String? translation;
  final bool autoTranslate;
  final int? category;
  final bool isOutputFiltered;
  final bool tonal;
  final String? tooltip;
  final VoidCallback? onDeleted;
  final String? deleteTooltip;

  const SimpleTagChip({
    super.key,
    required this.tag,
    this.color,
    this.onTap,
    this.onSecondaryTapDown,
    this.translation,
    this.autoTranslate = true,
    this.category,
    this.isOutputFiltered = false,
    this.tonal = false,
    this.tooltip,
    this.onDeleted,
    this.deleteTooltip,
  });

  @override
  ConsumerState<SimpleTagChip> createState() => _SimpleTagChipState();
}

class _SimpleTagChipState extends ConsumerState<SimpleTagChip> {
  bool _isHovering = false;
  String? _autoTranslation;

  @override
  void initState() {
    super.initState();
    if (widget.autoTranslate && widget.translation == null) {
      _fetchTranslation();
    }
  }

  @override
  void didUpdateWidget(SimpleTagChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag &&
        widget.autoTranslate &&
        widget.translation == null) {
      _fetchTranslation();
    }
  }

  Future<void> _fetchTranslation() async {
    final translationService = ref.read(tagTranslationLookupProvider);
    _autoTranslation = await translationService.translate(widget.tag);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = widget.tag.replaceAll('_', ' ');
    final chipColor =
        widget.color ??
        (widget.category != null
            ? TagColors.fromCategory(widget.category!)
            : theme.colorScheme.primary);
    final translationText = widget.translation ?? _autoTranslation;
    final stateColor = widget.isOutputFiltered
        ? theme.colorScheme.error
        : chipColor;

    final chip = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovering
                ? stateColor.withValues(alpha: widget.tonal ? 0.18 : 0.22)
                : stateColor.withValues(
                    alpha: widget.isOutputFiltered
                        ? 0.08
                        : widget.tonal
                        ? 0.11
                        : 0.1,
                  ),
            borderRadius: BorderRadius.circular(widget.tonal ? 7 : 4),
            border: widget.tonal
                ? null
                : Border.all(
                    color: stateColor.withValues(
                      alpha: _isHovering ? 0.8 : 0.35,
                    ),
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.tonal
                        ? theme.colorScheme.onSurface
                        : stateColor,
                    fontWeight: FontWeight.w500,
                    decoration: widget.isOutputFiltered
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              if (widget.isOutputFiltered) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.filter_alt_off_outlined,
                  size: 12,
                  color: theme.colorScheme.error,
                ),
              ],
              if (translationText != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    translationText,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
              if (widget.onDeleted != null) ...[
                const SizedBox(width: 3),
                Tooltip(
                  message: widget.deleteTooltip ?? '',
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: IconButton(
                      onPressed: widget.onDeleted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 20,
                        height: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 13, color: stateColor),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? chip
        : Tooltip(message: widget.tooltip!, child: chip);
  }
}

/// 带 Tooltip 的简单标签芯片
class SimpleTagChipWithTooltip extends StatelessWidget {
  final String tag;
  final Color? color;
  final VoidCallback? onTap;
  final String? translation;
  final int? category;
  final String? tooltipMessage;

  const SimpleTagChipWithTooltip({
    super.key,
    required this.tag,
    this.color,
    this.onTap,
    this.translation,
    this.category,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    final chip = SimpleTagChip(
      tag: tag,
      color: color,
      onTap: onTap,
      translation: translation,
      category: category,
    );

    if (tooltipMessage != null) {
      return Tooltip(message: tooltipMessage!, child: chip);
    }

    return chip;
  }
}

/// 标签分类颜色
class TagColors {
  static const Color artist = Color(0xFFFF8A8A); // 红色 - 艺术家
  static const Color character = Color(0xFF8AFF8A); // 绿色 - 角色
  static const Color copyright = Color(0xFFCC8AFF); // 紫色 - 版权/作品
  static const Color general = Color(0xFF8AC8FF); // 蓝色 - 通用
  static const Color meta = Color(0xFFFFB38A); // 橙色 - 元数据

  /// 根据 Danbooru 标签分类获取颜色
  /// - 0 = general (通用)
  /// - 1 = artist (艺术家)
  /// - 3 = copyright (版权)
  /// - 4 = character (角色)
  /// - 5 = meta (元数据)
  static Color fromCategory(int category) {
    switch (category) {
      case 1:
        return artist;
      case 3:
        return copyright;
      case 4:
        return character;
      case 5:
        return meta;
      default:
        return general;
    }
  }

  /// 根据分类名称获取颜色
  static Color fromCategoryName(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'artist':
        return artist;
      case 'copyright':
        return copyright;
      case 'character':
        return character;
      case 'meta':
        return meta;
      default:
        return general;
    }
  }
}
