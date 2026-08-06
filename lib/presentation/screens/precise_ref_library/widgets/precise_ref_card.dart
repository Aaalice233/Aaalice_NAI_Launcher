import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';

/// 精准参考库条目卡片
///
/// 缩略图按需从存储服务加载；悬停显示动作按钮。
/// 单击卡片等同于「发送到精准参考」。
class PreciseRefCard extends ConsumerStatefulWidget {
  const PreciseRefCard({
    super.key,
    required this.entry,
    this.onSendToPreciseRef,
    this.onSendToImg2Img,
    this.onEdit,
    this.onDelete,
    this.onToggleFavorite,
  });

  final PreciseRefLibraryEntry entry;
  final VoidCallback? onSendToPreciseRef;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorite;

  @override
  ConsumerState<PreciseRefCard> createState() => _PreciseRefCardState();
}

class _PreciseRefCardState extends ConsumerState<PreciseRefCard> {
  Uint8List? _thumbnail;
  bool _thumbnailRequested = false;
  bool _hovering = false;

  @override
  void didUpdateWidget(covariant PreciseRefCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _thumbnail = null;
      _thumbnailRequested = false;
    }
  }

  void _loadThumbnailIfNeeded() {
    if (_thumbnailRequested) return;
    _thumbnailRequested = true;
    final id = widget.entry.id;
    ref
        .read(preciseRefLibraryStorageServiceProvider)
        .getDisplayThumbnail(id)
        .then((bytes) {
          if (!mounted || widget.entry.id != id) return;
          setState(() => _thumbnail = bytes);
        });
  }

  String _typeDisplayName(BuildContext context) {
    final l10n = context.l10n;
    return widget.entry.type.getDisplayName(
      character: l10n.preciseRef_typeCharacter,
      style: l10n.preciseRef_typeStyle,
      characterAndStyle: l10n.preciseRef_typeCharacterAndStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadThumbnailIfNeeded();
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: _hovering ? 4 : 1,
        child: InkWell(
          onTap: widget.onSendToPreciseRef,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildThumbnailArea(theme)),
              _buildInfoArea(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailArea(ThemeData theme) {
    final entry = widget.entry;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_thumbnail != null)
          Image.memory(_thumbnail!, fit: BoxFit.cover, gaplessPlayback: true)
        else
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        // 类型徽标
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.type.icon,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  _typeDisplayName(context),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        // 收藏星标
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            key: Key('precise-ref-card-favorite-${entry.id}'),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(
              entry.isFavorite ? Icons.star : Icons.star_border,
              color: entry.isFavorite
                  ? Colors.amber
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: widget.onToggleFavorite,
          ),
        ),
        // 悬停动作层
        if (_hovering) _buildHoverActions(theme),
      ],
    );
  }

  Widget _buildHoverActions(ThemeData theme) {
    final l10n = context.l10n;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HoverActionButton(
                key: Key('precise-ref-card-send-${widget.entry.id}'),
                icon: Icons.center_focus_strong,
                label: l10n.preciseRefLib_sendToPreciseRef,
                primary: true,
                onTap: widget.onSendToPreciseRef,
              ),
              const SizedBox(height: 6),
              _HoverActionButton(
                key: Key('precise-ref-card-img2img-${widget.entry.id}'),
                icon: Icons.image_outlined,
                label: l10n.preciseRefLib_sendToImg2Img,
                onTap: widget.onSendToImg2Img,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HoverIconButton(
                    key: Key('precise-ref-card-edit-${widget.entry.id}'),
                    icon: Icons.edit_outlined,
                    tooltip: l10n.preciseRefLib_editEntry,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 8),
                  _HoverIconButton(
                    key: Key('precise-ref-card-delete-${widget.entry.id}'),
                    icon: Icons.delete_outline,
                    tooltip: l10n.preciseRefLib_deleteEntry,
                    isDestructive: true,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoArea(ThemeData theme) {
    final entry = widget.entry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'S ${_formatParam(entry.strength)} · F ${_formatParam(entry.fidelity)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatParam(double value) {
    final text = value.toStringAsFixed(2);
    if (text.endsWith('0')) {
      final shorter = value.toStringAsFixed(1);
      return shorter;
    }
    return text;
  }
}

class _HoverActionButton extends StatelessWidget {
  const _HoverActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.primary = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: primary ? theme.colorScheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: primary ? theme.colorScheme.onPrimary : Colors.black87,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: primary ? theme.colorScheme.onPrimary : Colors.black87,
                  fontWeight: primary ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatelessWidget {
  const _HoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.isDestructive = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              icon,
              size: 15,
              color: isDestructive ? Colors.red.shade700 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
