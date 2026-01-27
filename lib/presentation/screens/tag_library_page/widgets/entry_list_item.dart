import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';

/// 词库条目列表项
class EntryListItem extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onAddToFixed;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const EntryListItem({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAddToFixed,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  State<EntryListItem> createState() => _EntryListItemState();
}

class _EntryListItemState extends State<EntryListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovering
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              // 预览图
              _buildThumbnail(theme, entry),
              const SizedBox(width: 16),

              // 信息
              Expanded(
                child: _buildInfo(theme, entry),
              ),

              // 操作按钮
              if (_isHovering) ...[
                const SizedBox(width: 12),
                _buildActions(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme, TagLibraryEntry entry) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: entry.hasThumbnail
            ? Image.file(
                File(entry.thumbnail!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    _buildPlaceholder(theme),
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: theme.colorScheme.outline.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildInfo(ThemeData theme, TagLibraryEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 名称行
        Row(
          children: [
            // 收藏图标
            if (entry.isFavorite)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber.shade600,
                ),
              ),

            // 名称
            Expanded(
              child: Text(
                entry.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 使用次数
            if (entry.useCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.useCount.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 4),

        // 内容预览
        Text(
          entry.contentPreview,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // 标签
        if (entry.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                entry.tags.take(4).map((tag) => _TagChip(tag: tag)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            widget.entry.isFavorite ? Icons.star : Icons.star_outline,
            color: widget.entry.isFavorite ? Colors.amber : null,
          ),
          tooltip: widget.entry.isFavorite
              ? context.l10n.tagLibrary_removeFavorite
              : context.l10n.tagLibrary_addFavorite,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onToggleFavorite,
        ),
        IconButton(
          icon: const Icon(Icons.push_pin_outlined),
          tooltip: context.l10n.tagLibrary_addToFixed,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onAddToFixed,
        ),
        IconButton(
          icon: const Icon(Icons.content_copy),
          tooltip: context.l10n.common_copy,
          visualDensity: VisualDensity.compact,
          onPressed: () => _copyToClipboard(widget.entry.content),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          tooltip: context.l10n.common_delete,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_copied),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 标签小芯片
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
