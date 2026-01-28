import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/prompt_preset_mode.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/quality_preset_provider.dart';
import '../tag_library/tag_library_picker_dialog.dart';

/// 质量词选择器组件
///
/// 显示下拉菜单，支持选择 NAI 默认、无、或从词库添加自定义质量词
class QualityTagsSelector extends ConsumerStatefulWidget {
  /// 当前选择的模型
  final String model;

  const QualityTagsSelector({
    super.key,
    required this.model,
  });

  @override
  ConsumerState<QualityTagsSelector> createState() =>
      _QualityTagsSelectorState();
}

class _QualityTagsSelectorState extends ConsumerState<QualityTagsSelector> {
  bool _isHovering = false;
  final _layerLink = LayerLink();
  final _buttonKey = GlobalKey();
  OverlayEntry? _previewOverlay;

  @override
  void dispose() {
    _hidePreviewOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetState = ref.watch(qualityPresetNotifierProvider);
    final customEntries = ref.watch(qualityCustomEntriesProvider);
    final isEnabled = presetState.mode != PromptPresetMode.none;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        richMessage: WidgetSpan(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: _buildTooltipContent(theme, presetState, customEntries),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => _showMenu(context, presetState, customEntries),
          child: CompositedTransformTarget(
            key: _buttonKey,
            link: _layerLink,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEnabled
                    ? (_isHovering
                        ? Colors.green.withOpacity(0.2)
                        : Colors.green.withOpacity(0.1))
                    : (_isHovering
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isEnabled
                      ? Colors.green.withOpacity(0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEnabled
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    size: 14,
                    color: isEnabled
                        ? Colors.green.shade700
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getDisplayLabel(context, presetState, customEntries),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                      color: isEnabled
                          ? Colors.green.shade700
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 14,
                    color: isEnabled
                        ? Colors.green.shade700
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    QualityPresetState presetState,
    List<TagLibraryEntry> customEntries,
  ) async {
    final RenderBox button =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    // 菜单位置：按钮正下方，左边缘对齐
    final position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + buttonSize.height,
      overlay.size.width - buttonPosition.dx - buttonSize.width,
      0,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: _buildMenuItems(context, presetState, customEntries),
    );

    if (result != null) {
      _onMenuItemSelected(result);
    }
  }

  String _getDisplayLabel(
    BuildContext context,
    QualityPresetState state,
    List<TagLibraryEntry> customEntries,
  ) {
    switch (state.mode) {
      case PromptPresetMode.naiDefault:
        return context.l10n.qualityTags_label;
      case PromptPresetMode.none:
        return context.l10n.qualityTags_none;
      case PromptPresetMode.custom:
        // 找到当前选中的条目
        final currentEntry = customEntries.cast<TagLibraryEntry?>().firstWhere(
              (e) => e?.id == state.customEntryId,
              orElse: () => null,
            );
        if (currentEntry != null) {
          // 截断名称
          final name = currentEntry.displayName;
          return name.length > 8 ? '${name.substring(0, 8)}...' : name;
        }
        return context.l10n.qualityTags_label;
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context,
    QualityPresetState state,
    List<TagLibraryEntry> customEntries,
  ) {
    final theme = Theme.of(context);
    final items = <PopupMenuEntry<String>>[];

    // NAI 默认
    items.add(PopupMenuItem<String>(
      value: 'nai_default',
      child: Row(
        children: [
          if (state.mode == PromptPresetMode.naiDefault)
            Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(
            context.l10n.qualityTags_naiDefault,
            style: TextStyle(
              fontWeight: state.mode == PromptPresetMode.naiDefault
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: state.mode == PromptPresetMode.naiDefault
                  ? theme.colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
    ));

    // 无
    items.add(PopupMenuItem<String>(
      value: 'none',
      child: Row(
        children: [
          if (state.mode == PromptPresetMode.none)
            Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(
            context.l10n.qualityTags_none,
            style: TextStyle(
              fontWeight: state.mode == PromptPresetMode.none
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: state.mode == PromptPresetMode.none
                  ? theme.colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
    ));

    // 分隔线
    items.add(const PopupMenuDivider());

    // 从词库添加
    items.add(PopupMenuItem<String>(
      value: 'add_from_library',
      child: Row(
        children: [
          Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            context.l10n.qualityTags_addFromLibrary,
            style: TextStyle(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    ));

    // 所有已添加的自定义条目
    if (customEntries.isNotEmpty) {
      items.add(const PopupMenuDivider());
      for (final entry in customEntries) {
        final isSelected = state.mode == PromptPresetMode.custom &&
            state.customEntryId == entry.id;
        items.add(_CustomEntryMenuItem(
          entry: entry,
          isSelected: isSelected,
          onDelete: () {
            ref
                .read(qualityPresetNotifierProvider.notifier)
                .removeCustomEntry(entry.id);
            Navigator.of(context).pop();
          },
        ));
      }
    }

    return items;
  }

  void _onMenuItemSelected(String value) {
    switch (value) {
      case 'nai_default':
        ref.read(qualityPresetNotifierProvider.notifier).setNaiDefault();
        break;
      case 'none':
        ref.read(qualityPresetNotifierProvider.notifier).setNone();
        break;
      case 'add_from_library':
        _showTagLibraryPicker();
        break;
      default:
        // 选择自定义条目
        if (value.startsWith('custom_')) {
          final entryId = value.substring(7);
          ref
              .read(qualityPresetNotifierProvider.notifier)
              .setCustomEntry(entryId);
        }
    }
  }

  Future<void> _showTagLibraryPicker() async {
    final entry = await showDialog<TagLibraryEntry>(
      context: context,
      builder: (context) => TagLibraryPickerDialog(
        title: context.l10n.qualityTags_selectFromLibrary,
      ),
    );
    if (entry != null) {
      ref.read(qualityPresetNotifierProvider.notifier).setCustomEntry(entry.id);
    }
  }

  Widget _buildTooltipContent(
    ThemeData theme,
    QualityPresetState state,
    List<TagLibraryEntry> customEntries,
  ) {
    if (state.mode == PromptPresetMode.none) {
      return Text(
        context.l10n.qualityTags_disabled,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 12,
        ),
      );
    }

    String content;
    if (state.mode == PromptPresetMode.custom && state.customEntryId != null) {
      final currentEntry = customEntries.cast<TagLibraryEntry?>().firstWhere(
            (e) => e?.id == state.customEntryId,
            orElse: () => null,
          );
      content = currentEntry?.content ??
          QualityTags.getQualityTags(widget.model) ??
          'very aesthetic, masterpiece, no text';
    } else {
      content = QualityTags.getQualityTags(widget.model) ??
          'very aesthetic, masterpiece, no text';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.qualityTags_addToEnd,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ', $content',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _hidePreviewOverlay() {
    _previewOverlay?.remove();
    _previewOverlay = null;
  }
}

/// 自定义条目菜单项
class _CustomEntryMenuItem extends PopupMenuEntry<String> {
  final TagLibraryEntry entry;
  final bool isSelected;
  final VoidCallback onDelete;

  const _CustomEntryMenuItem({
    required this.entry,
    required this.isSelected,
    required this.onDelete,
  });

  @override
  double get height => 56;

  @override
  bool represents(String? value) => value == 'custom_${entry.id}';

  @override
  State<_CustomEntryMenuItem> createState() => _CustomEntryMenuItemState();
}

class _CustomEntryMenuItemState extends State<_CustomEntryMenuItem> {
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
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              size: 20,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.library_books_outlined,
                            size: 20,
                            color: theme.colorScheme.outline,
                          ),
                        ),
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
                  tooltip: context.l10n.common_delete,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
