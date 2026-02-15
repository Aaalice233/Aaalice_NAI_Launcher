import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/models/tag_library/tag_library_entry.dart';

/// 词库条目菜单项组件
///
/// 用于 QualityTagsSelector 和 UcPresetSelector 的自定义条目菜单
class LibraryEntryMenuItem extends PopupMenuEntry<String> {
  final TagLibraryEntry entry;
  final bool isSelected;
  final VoidCallback onDelete;

  const LibraryEntryMenuItem({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onDelete,
  });

  @override
  double get height => 56;

  @override
  bool represents(String? value) => value == 'custom_${entry.id}';

  @override
  State<LibraryEntryMenuItem> createState() => _LibraryEntryMenuItemState();
}

class _LibraryEntryMenuItemState extends State<LibraryEntryMenuItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: () => Navigator.of(context).pop('custom_${widget.entry.id}'),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 选中指示
              if (widget.isSelected)
                Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),

              // 缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: widget.entry.hasThumbnail
                      ? Image.file(
                          File(widget.entry.thumbnail!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                        )
                      : _buildPlaceholder(theme),
                ),
              ),
              const SizedBox(width: 12),

              // 名称和内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.entry.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: widget.isSelected
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.entry.contentPreview,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 删除按钮（悬浮时显示）
              AnimatedOpacity(
                opacity: _isHovering ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.library_books_outlined,
        size: 20,
        color: theme.colorScheme.outline,
      ),
    );
  }
}
