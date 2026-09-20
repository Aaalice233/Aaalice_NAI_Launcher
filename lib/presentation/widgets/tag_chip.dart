import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/tag_translation_lookup.dart';
import '../adaptive/interaction_policy.dart';

/// 简单标签芯片组件
///
/// 显示带颜色的标签，支持点击和自动翻译
/// 用于在线画廊、权重调整等简单场景
class SimpleTagChip extends ConsumerStatefulWidget {
  final String tag;
  final Color? color;
  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;

  /// 长按回调。
  ///
  /// 偏离上游：上游只有 [onSecondaryTapUp]（右键），触屏没有右键，
  /// 于是标签的「加入黑名单 / 输出过滤」菜单在 iOS 上完全不可达。
  /// 不传时自动复用 [onSecondaryTapUp]，把长按位置合成成同形状的
  /// [TapUpDetails] 交给同一个菜单回调——调用方不改也能在手机上用。
  final GestureLongPressStartCallback? onLongPressStart;
  final String? translation;
  final bool autoTranslate;
  final int? category;
  final bool isOutputFiltered;
  final String? tooltip;
  final VoidCallback? onDeleted;
  final String? deleteTooltip;

  const SimpleTagChip({
    super.key,
    required this.tag,
    this.color,
    this.onTap,
    this.onSecondaryTapUp,
    this.onLongPressStart,
    this.translation,
    this.autoTranslate = true,
    this.category,
    this.isOutputFiltered = false,
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

  /// 长按走与右键相同的菜单：显式传入优先，否则复用
  /// [SimpleTagChip.onSecondaryTapUp]（详见该字段的注释）。
  GestureLongPressStartCallback? _resolveLongPressStart() {
    final explicit = widget.onLongPressStart;
    if (explicit != null) return explicit;

    final secondary = widget.onSecondaryTapUp;
    if (secondary == null) return null;

    return (details) {
      HapticFeedback.selectionClick();
      // 菜单只用得到 globalPosition，长按位置直接转成同形状的 details
      secondary(
        TapUpDetails(
          kind: PointerDeviceKind.touch,
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
        ),
      );
    };
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
    final interactionPolicy = context.interactionPolicy;
    final deleteExtent = interactionPolicy.minimumControlExtent;
    final stateColor = widget.isOutputFiltered
        ? theme.colorScheme.error
        : chipColor;

    final chip = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovering
                ? stateColor.withValues(alpha: 0.22)
                : stateColor.withValues(
                    alpha: widget.isOutputFiltered ? 0.08 : 0.1,
                  ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 11,
                    color: stateColor,
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
                  child: SizedBox.square(
                    dimension: deleteExtent,
                    child: IconButton(
                      onPressed: widget.onDeleted,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: deleteExtent,
                        height: deleteExtent,
                      ),
                      visualDensity: interactionPolicy.touchAvailable
                          ? VisualDensity.standard
                          : VisualDensity.compact,
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
    // InkWell 的 onLongPress 不带坐标，而标签菜单要用 globalPosition 定位，
    // 所以长按识别器单独包在外层（与 InkWell 的 tap 在手势竞技场里互斥）。
    final longPressStart = _resolveLongPressStart();
    final interactiveChip = longPressStart == null
        ? chip
        : GestureDetector(onLongPressStart: longPressStart, child: chip);
    return widget.tooltip == null
        ? interactiveChip
        : Tooltip(message: widget.tooltip!, child: interactiveChip);
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
