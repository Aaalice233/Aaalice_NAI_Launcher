import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/app_toast.dart';

/// 词库条目列表项
class EntryListItem extends StatefulWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onAddToFixed;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;

  const EntryListItem({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAddToFixed,
    required this.onDelete,
    required this.onToggleFavorite,
    this.onEdit,
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovering
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outlineVariant.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
            // 置顶图标
            if (entry.isFavorite)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.push_pin,
                  size: 12,
                  color: Colors.white,
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
        // 置顶按钮
        widget.entry.isFavorite
            ? Material(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: widget.onToggleFavorite,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.push_pin,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.tagLibrary_pinned,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.push_pin_outlined),
                tooltip: context.l10n.tagLibrary_addFavorite,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onToggleFavorite,
              ),
        // 编辑按钮
        if (widget.onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.l10n.common_edit,
            visualDensity: VisualDensity.compact,
            onPressed: widget.onEdit,
          ),
        // 添加到固定词
        IconButton(
          icon: const Icon(Icons.add_box_outlined),
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
    AppToast.success(context, context.l10n.common_copied);
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
