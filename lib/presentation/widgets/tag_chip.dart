import 'package:flutter/material.dart';

/// 标签芯片组件
///
/// 显示带颜色的标签，支持点击
class TagChip extends StatefulWidget {
  final String tag;
  final Color? color;
  final VoidCallback? onTap;
  final String? translation;

  const TagChip({
    super.key,
    required this.tag,
    this.color,
    this.onTap,
    this.translation,
  });

  @override
  State<TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<TagChip> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = widget.tag.replaceAll('_', ' ');
    final chipColor = widget.color ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovering
                ? chipColor.withOpacity(0.3)
                : chipColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: chipColor.withOpacity(_isHovering ? 0.8 : 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 11,
                  color: chipColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.translation != null) ...[
                const SizedBox(width: 4),
                Text(
                  widget.translation!,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 标签分类颜色
class TagColors {
  static const Color artist = Color(0xFFFF8A8A);     // 红色 - 艺术家
  static const Color character = Color(0xFF8AFF8A); // 绿色 - 角色
  static const Color copyright = Color(0xFFCC8AFF); // 紫色 - 版权/作品
  static const Color general = Color(0xFF8AC8FF);   // 蓝色 - 通用
  static const Color meta = Color(0xFFFFB38A);      // 橙色 - 元数据

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
}

