import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../router/app_router.dart';
import '../common/themed_confirm_dialog.dart';
import '../common/themed_switch.dart';
import 'fixed_tag_edit_dialog.dart';

import '../common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 固定词管理对话框
class FixedTagsDialog extends ConsumerStatefulWidget {
  const FixedTagsDialog({super.key});

  @override
  ConsumerState<FixedTagsDialog> createState() => _FixedTagsDialogState();
}

class _FixedTagsDialogState extends ConsumerState<FixedTagsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final entries = fixedTagsState.entries;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 520,
              maxHeight: 620,
              minWidth: 420,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withOpacity(0.85)
                  : theme.colorScheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                if (isDark)
                  BoxShadow(
                    color: theme.colorScheme.secondary.withOpacity(0.08),
                    blurRadius: 48,
                    spreadRadius: -8,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                _buildHeader(theme, isDark),

                // 列表区域
                Flexible(
                  child: entries.isEmpty
                      ? _buildEmptyState(theme, isDark)
                      : _buildEntryList(theme, entries, isDark),
                ),

                // 底部操作栏
                _buildFooter(theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final enabledCount = ref.watch(enabledFixedTagsCountProvider);
    final totalCount = ref.watch(fixedTagsCountProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary.withOpacity(isDark ? 0.08 : 0.05),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // 图标容器增加渐变背景
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.secondary.withOpacity(0.2),
                  theme.colorScheme.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.push_pin_rounded,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.fixedTags_manage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                if (totalCount > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: enabledCount > 0
                              ? theme.colorScheme.secondary.withOpacity(0.15)
                              : theme.colorScheme.outline.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.l10n.fixedTags_enabledCount(
                            enabledCount.toString(),
                            totalCount.toString(),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: enabledCount > 0
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 全开/全关切换按钮
          if (totalCount > 0) ...[
            ThemedSwitch(
              value: enabledCount == totalCount,
              onChanged: (value) {
                ref
                    .read(fixedTagsNotifierProvider.notifier)
                    .setAllEnabled(value);
              },
              scale: 0.85,
            ),
            const SizedBox(width: 8),
          ],
          // 关闭按钮美化
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.fixedTags_empty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.fixedTags_emptyHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList(
    ThemeData theme,
    List<FixedTagEntry> entries,
    bool isDark,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _FixedTagEntryTile(
          key: ValueKey(entry.id),
          entry: entry,
          index: index,
          isDark: isDark,
          onToggleEnabled: () {
            ref
                .read(fixedTagsNotifierProvider.notifier)
                .toggleEnabled(entry.id);
          },
          onEdit: () => _showEditDialog(entry),
          onDelete: () => _showDeleteConfirmation(entry),
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorder(oldIndex, newIndex);
      },
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    final hasEntries = ref.watch(fixedTagsNotifierProvider).entries.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // 打开词库按钮 - 轮廓样式
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.tagLibraryPage);
            },
            icon: const Icon(Icons.library_books_outlined, size: 17),
            label: Text(context.l10n.fixedTags_openLibrary),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          // 清空按钮 - 危险操作
          if (hasEntries)
            OutlinedButton.icon(
              onPressed: _showClearAllConfirmation,
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: 17,
                color: theme.colorScheme.error,
              ),
              label: Text(
                context.l10n.fixedTags_clearAll,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                side:
                    BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
              ),
            ),
          const Spacer(),
          // 添加按钮 - 次要
          FilledButton.tonalIcon(
            onPressed: () => _showEditDialog(null),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(context.l10n.fixedTags_add),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          // 从词库添加按钮 - 主要（最常用）
          FilledButton.icon(
            onPressed: () => _showLibraryPicker(theme),
            icon: const Icon(Icons.playlist_add_rounded, size: 17),
            label: const Text('从词库添加'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示词库选择器
  void _showLibraryPicker(ThemeData theme) {
    final libraryState = ref.read(tagLibraryPageNotifierProvider);
    final entries = libraryState.entries;

    if (entries.isEmpty) {
      AppToast.info(context, '词库为空，请先添加条目');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _LibraryPickerDialog(
        entries: entries,
        onSelect: _addFromLibrary,
      ),
    );
  }

  /// 从词库添加条目
  Future<void> _addFromLibrary(TagLibraryEntry entry) async {
    await ref.read(fixedTagsNotifierProvider.notifier).addEntry(
          name: entry.name,
          content: entry.content,
          weight: 1.0,
          position: FixedTagPosition.prefix,
          enabled: true,
        );
  }

  void _showEditDialog(FixedTagEntry? entry) async {
    final result = await showDialog<FixedTagEntry>(
      context: context,
      builder: (context) => FixedTagEditDialog(entry: entry),
    );

    if (result != null) {
      if (entry == null) {
        // 新建
        await ref.read(fixedTagsNotifierProvider.notifier).addEntry(
              name: result.name,
              content: result.content,
              weight: result.weight,
              position: result.position,
              enabled: result.enabled,
            );
      } else {
        // 更新
        await ref.read(fixedTagsNotifierProvider.notifier).updateEntry(result);
      }
    }
  }

  void _showDeleteConfirmation(FixedTagEntry entry) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_deleteTitle,
      content: context.l10n.fixedTags_deleteConfirm(entry.displayName),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      ref.read(fixedTagsNotifierProvider.notifier).deleteEntry(entry.id);
    }
  }

  /// 显示清空所有固定词确认对话框
  void _showClearAllConfirmation() async {
    final entriesCount = ref.read(fixedTagsNotifierProvider).entries.length;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_clearAllTitle,
      content: context.l10n.fixedTags_clearAllConfirm(entriesCount),
      confirmText: context.l10n.fixedTags_clearAll,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );

    if (confirmed && mounted) {
      ref.read(fixedTagsNotifierProvider.notifier).clearAll();
      AppToast.success(context, context.l10n.fixedTags_clearedSuccess);
    }
  }
}

/// 词库选择对话框
class _LibraryPickerDialog extends StatefulWidget {
  final List<TagLibraryEntry> entries;
  final ValueChanged<TagLibraryEntry> onSelect;

  const _LibraryPickerDialog({
    required this.entries,
    required this.onSelect,
  });

  @override
  State<_LibraryPickerDialog> createState() => _LibraryPickerDialogState();
}

class _LibraryPickerDialogState extends State<_LibraryPickerDialog> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<TagLibraryEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return widget.entries;
    final query = _searchQuery.toLowerCase();
    return widget.entries.where((e) {
      return e.name.toLowerCase().contains(query) ||
          e.content.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredEntries;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
          maxHeight: 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '从词库添加',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ThemedInput(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索词库条目...',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 4),
            // 列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '无匹配结果',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        return _LibraryEntryTile(
                          entry: entry,
                          onTap: () {
                            widget.onSelect(entry);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// 词库条目选项
class _LibraryEntryTile extends StatelessWidget {
  final TagLibraryEntry entry;
  final VoidCallback onTap;

  const _LibraryEntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.isNotEmpty ? entry.name : entry.content,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.name.isNotEmpty && entry.content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.content.replaceAll('\n', ' '),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.add_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 固定词条目卡片 - 紧凑版
class _FixedTagEntryTile extends StatefulWidget {
  final FixedTagEntry entry;
  final int index;
  final bool isDark;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedTagEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.isDark,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_FixedTagEntryTile> createState() => _FixedTagEntryTileState();
}

class _FixedTagEntryTileState extends State<_FixedTagEntryTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final isDark = widget.isDark;

    // 位置颜色
    final posColor =
        entry.isPrefix ? theme.colorScheme.primary : theme.colorScheme.tertiary;

    // 禁用状态透明度
    final disabledOpacity = entry.enabled ? 1.0 : 0.5;

    return ReorderableDragStartListener(
      index: widget.index,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // 色差背景：启用时用主题色深背景，禁用时发灰
            color: entry.enabled
                ? (isDark
                    ? theme.colorScheme.surfaceContainerHigh
                    : theme.colorScheme.surfaceContainerHighest)
                : theme.colorScheme.surfaceContainerLow.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            // 无边框 + 阴影
            boxShadow: entry.enabled
                ? [
                    BoxShadow(
                      color: theme.colorScheme.shadow
                          .withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: -2,
                    ),
                    if (_isHovering)
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ]
                : [
                    // 禁用状态也有轻微阴影
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: disabledOpacity,
            child: Row(
              children: [
                // 启用开关
                ThemedSwitch(
                  value: entry.enabled,
                  onChanged: (_) => widget.onToggleEnabled(),
                  scale: 0.7,
                ),

                const SizedBox(width: 10),

                // 名称 + 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 名称
                      Text(
                        entry.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: entry.enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                          // 禁用时显示删除线
                          decoration:
                              entry.enabled ? null : TextDecoration.lineThrough,
                          decorationColor:
                              theme.colorScheme.outline.withOpacity(0.6),
                          decorationThickness: 2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      // 内容预览 - 仅内容与名称不同时显示
                      if (entry.content.isNotEmpty &&
                          entry.content != entry.displayName)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            entry.content.replaceAll('\n', ' '),
                            style: TextStyle(
                              fontSize: 11,
                              color: entry.enabled
                                  ? theme.colorScheme.outline.withOpacity(0.8)
                                  : theme.colorScheme.outline.withOpacity(0.5),
                              height: 1.2,
                              decoration: entry.enabled
                                  ? null
                                  : TextDecoration.lineThrough,
                              decorationColor:
                                  theme.colorScheme.outline.withOpacity(0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 标签区 - 紧凑
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 位置标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: entry.enabled
                            ? posColor.withOpacity(0.15)
                            : theme.colorScheme.outline.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.isPrefix
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_back_rounded,
                            size: 10,
                            color: entry.enabled
                                ? posColor
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            entry.isPrefix
                                ? context.l10n.fixedTags_prefix
                                : context.l10n.fixedTags_suffix,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: entry.enabled
                                  ? posColor
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 权重标签
                    if (entry.weight != 1.0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: entry.enabled
                              ? theme.colorScheme.secondary.withOpacity(0.15)
                              : theme.colorScheme.outline.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entry.weight.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: entry.enabled
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(width: 6),

                // 操作按钮 - 紧凑
                AnimatedOpacity(
                  opacity: _isHovering ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CompactIconButton(
                        icon: Icons.edit_outlined,
                        onPressed: widget.onEdit,
                        tooltip: context.l10n.common_edit,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        hoverColor: theme.colorScheme.primary,
                      ),
                      _CompactIconButton(
                        icon: Icons.close_rounded,
                        onPressed: widget.onDelete,
                        tooltip: context.l10n.common_delete,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        hoverColor: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 紧凑图标按钮
class _CompactIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;
  final Color hoverColor;

  const _CompactIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    required this.hoverColor,
  });

  @override
  State<_CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<_CompactIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              widget.icon,
              size: 15,
              color: _isHovering ? widget.hoverColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
