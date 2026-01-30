import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../common/app_toast.dart';
import '../new_preset_dialog.dart';
import 'random_manager_widgets.dart';

/// 预设选择栏组件
///
/// 显示预设下拉选择、统计信息和操作按钮
/// 采用 Dimensional Layering 风格设计
class PresetSelectorBar extends ConsumerWidget {
  const PresetSelectorBar({
    super.key,
    this.onGeneratePreview,
    this.onImportExport,
  });

  final VoidCallback? onGeneratePreview;
  final VoidCallback? onImportExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final selectedPreset = presetState.selectedPreset;
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 方案: 微妙深色工具栏 - 比内容区稍深，有独立背景色
    // 背景色填充整个区域，内部 padding 不会显示为间隔
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // 稍深的背景色，与内容区形成微妙对比
        color: Color.alphaBlend(
          Colors.black.withOpacity(0.15),
          colorScheme.surfaceContainerHighest,
        ),
        // 底部分隔线
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.25),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 响应式布局：窄屏时垂直排列
          final isNarrow = constraints.maxWidth < 600;

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 预设选择下拉框
                _PresetDropdown(
                  presets: presetState.presets,
                  selectedPreset: selectedPreset,
                  onSelected: (preset) {
                    ref
                        .read(randomPresetNotifierProvider.notifier)
                        .selectPreset(preset.id);
                  },
                  onCreateNew: () => _showCreatePresetDialog(context, ref),
                ),
                // 只读模式提示（窄屏时单独一行）
                if (selectedPreset?.isDefault == true) ...[
                  const SizedBox(height: 8),
                  const _ReadOnlyIndicator(),
                ],
                const SizedBox(height: 12),
                // 统计信息 + 操作按钮
                Row(
                  children: [
                    if (selectedPreset != null)
                      Expanded(
                        child: _StatisticsInfo(preset: selectedPreset),
                      ),
                    _ActionButtons(
                      onDelete: selectedPreset != null &&
                              !selectedPreset.isDefault
                          ? () => _deletePreset(context, ref, selectedPreset)
                          : null,
                      onResetToDefault: selectedPreset != null &&
                              !selectedPreset.isDefault &&
                              selectedPreset.isBasedOnDefault
                          ? () => _resetToDefault(context, ref, selectedPreset)
                          : null,
                      onGeneratePreview: onGeneratePreview,
                      onImportExport: onImportExport,
                      onSync:
                          selectedPreset != null && !selectedPreset.isDefault
                              ? () => _syncDanbooru(context, ref)
                              : null,
                      isSyncing: syncState.isSyncing,
                    ),
                  ],
                ),
              ],
            );
          }

          // 宽屏布局：横向排列，带分隔线
          return Row(
            children: [
              // 预设选择下拉框 - 固定宽度
              SizedBox(
                width: 220,
                child: _PresetDropdown(
                  presets: presetState.presets,
                  selectedPreset: selectedPreset,
                  onSelected: (preset) {
                    ref
                        .read(randomPresetNotifierProvider.notifier)
                        .selectPreset(preset.id);
                  },
                  onCreateNew: () => _showCreatePresetDialog(context, ref),
                ),
              ),
              // 垂直分隔线
              _VerticalDivider(color: colorScheme.primary),
              // 全局信息区域 - 显示预设描述 + 只读提示
              Expanded(
                child: Row(
                  children: [
                    if (selectedPreset?.description != null &&
                        selectedPreset!.description!.isNotEmpty)
                      Flexible(
                        child: Text(
                          selectedPreset.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 只读模式提示（默认预设时显示）
                    if (selectedPreset?.isDefault == true) ...[
                      const SizedBox(width: 12),
                      const _ReadOnlyIndicator(),
                    ],
                  ],
                ),
              ),
              // 垂直分隔线
              _VerticalDivider(color: colorScheme.secondary),
              // 操作按钮组
              _ActionButtons(
                onDelete: selectedPreset != null && !selectedPreset.isDefault
                    ? () => _deletePreset(context, ref, selectedPreset)
                    : null,
                onResetToDefault: selectedPreset != null &&
                        !selectedPreset.isDefault &&
                        selectedPreset.isBasedOnDefault
                    ? () => _resetToDefault(context, ref, selectedPreset)
                    : null,
                onGeneratePreview: onGeneratePreview,
                onImportExport: onImportExport,
                onSync: selectedPreset != null && !selectedPreset.isDefault
                    ? () => _syncDanbooru(context, ref)
                    : null,
                isSyncing: syncState.isSyncing,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 显示创建预设对话框
  Future<void> _showCreatePresetDialog(
      BuildContext context, WidgetRef ref,) async {
    final result = await NewPresetDialog.show(context);
    if (result == null) return;

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final copyFromDefault = result.mode == PresetCreationMode.template;

    final newPreset = await notifier.createPreset(
      name: result.name,
      copyFromCurrent: copyFromDefault,
    );
    await notifier.selectPreset(newPreset.id);

    if (context.mounted) {
      AppToast.success(context, '已创建预设 "${result.name}"');
    }
  }

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定要删除 "${preset.name}" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .deletePreset(preset.id);
    }
  }

  Future<void> _syncDanbooru(BuildContext context, WidgetRef ref) async {
    final syncNotifier = ref.read(tagGroupSyncNotifierProvider.notifier);
    final success = await syncNotifier.syncTagGroups();

    if (context.mounted) {
      if (success) {
        AppToast.success(context, 'Danbooru 标签同步完成');
      } else {
        final error = ref.read(tagGroupSyncNotifierProvider).error;
        AppToast.error(context, '同步失败: ${error ?? "未知错误"}');
      }
    }
  }

  Future<void> _resetToDefault(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置为默认配置'),
        content: const Text('将恢复官方默认配置。\n您添加的自定义词组会被保留但禁用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .resetToDefault(preset.id);
      if (context.mounted) {
        AppToast.success(context, '已重置为默认配置');
      }
    }
  }
}

class _PresetDropdown extends StatefulWidget {
  const _PresetDropdown({
    required this.presets,
    required this.selectedPreset,
    required this.onSelected,
    required this.onCreateNew,
  });

  final List<RandomPreset> presets;
  final RandomPreset? selectedPreset;
  final ValueChanged<RandomPreset> onSelected;
  final VoidCallback onCreateNew;

  @override
  State<_PresetDropdown> createState() => _PresetDropdownState();
}

class _PresetDropdownState extends State<_PresetDropdown> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: _isHovered
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isHovered
                ? colorScheme.primary.withOpacity(0.3)
                : colorScheme.outlineVariant.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: DropdownButton<String>(
          value: widget.selectedPreset?.id,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          isDense: true,
          icon: AnimatedRotation(
            duration: const Duration(milliseconds: 150),
            turns: 0,
            child: Icon(
              Icons.expand_more,
              size: 18,
              color: _isHovered
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
          ),
          items: [
            // 现有预设列表
            ...widget.presets.map((preset) {
              return DropdownMenuItem<String>(
                value: preset.id,
                child: Row(
                  children: [
                    Icon(
                      preset.isDefault
                          ? Icons.star_rounded
                          : Icons.folder_outlined,
                      size: 14,
                      color: preset.isDefault
                          ? Colors.amber
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        preset.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // 分隔线 + 新建预设选项（开发中）
            DropdownMenuItem<String>(
              value: '__create_new__',
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: colorScheme.onSurface.withOpacity(0.35),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '新建预设...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (id) {
            if (id == '__create_new__') {
              AppToast.warning(context, '开发中');
            } else if (id != null) {
              final preset = widget.presets.firstWhere((p) => p.id == id);
              widget.onSelected(preset);
            }
          },
        ),
      ),
    );
  }
}

class _StatisticsInfo extends StatelessWidget {
  const _StatisticsInfo({required this.preset});

  final RandomPreset preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHigh.withOpacity(0.8),
            colorScheme.surfaceContainerHighest.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: StatItem(
              icon: Icons.category_outlined,
              label: '类别',
              value: '${preset.categoryCount}',
              color: colorScheme.primary,
            ),
          ),
          _GradientDivider(color: colorScheme.primary),
          Flexible(
            child: StatItem(
              icon: Icons.layers_outlined,
              label: '词组',
              value:
                  '${preset.categories.fold(0, (sum, c) => sum + c.groupCount)}',
              color: colorScheme.secondary,
            ),
          ),
          _GradientDivider(color: colorScheme.secondary),
          Flexible(
            child: StatItem(
              icon: Icons.label_outlined,
              label: '标签',
              value: '${preset.totalTagCount}',
              color: colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 渐变分隔线
class _GradientDivider extends StatelessWidget {
  const _GradientDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.0),
            color.withOpacity(0.4),
            color.withOpacity(0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// 垂直分隔线组件
class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0),
            color.withOpacity(0.4),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    this.onDelete,
    this.onResetToDefault,
    this.onGeneratePreview,
    this.onImportExport,
    this.onSync,
    this.isSyncing = false,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onResetToDefault;
  final VoidCallback? onGeneratePreview;
  final VoidCallback? onImportExport;
  final VoidCallback? onSync;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Danbooru 同步按钮（默认预设不显示）
        if (onSync != null) ...[
          _SyncButton(
            onPressed: onSync,
            isSyncing: isSyncing,
          ),
          const SizedBox(width: 4),
        ],
        // 生成预览按钮
        if (onGeneratePreview != null)
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            tooltip: '生成预览',
            onPressed: onGeneratePreview,
            color: colorScheme.primary,
          ),
        // 重置为默认按钮
        if (onResetToDefault != null) _ResetButton(onPressed: onResetToDefault),
        // 删除按钮
        if (onDelete != null)
          _ActionButton(
            icon: Icons.delete_outline,
            tooltip: '删除预设',
            onPressed: onDelete,
            color: Colors.red.shade400,
          ),
        // 导入/导出按钮
        if (onImportExport != null)
          _ActionButton(
            icon: Icons.import_export,
            tooltip: '导入/导出',
            onPressed: onImportExport,
          ),
      ],
    );
  }
}

/// Danbooru 同步按钮组件
class _SyncButton extends StatefulWidget {
  const _SyncButton({
    this.onPressed,
    this.isSyncing = false,
  });

  final VoidCallback? onPressed;
  final bool isSyncing;

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isSyncing) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSyncing && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isSyncing && _animController.isAnimating) {
      _animController.stop();
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const syncColor = Colors.teal;

    return MouseRegion(
      cursor:
          widget.isSyncing ? SystemMouseCursors.wait : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.isSyncing ? '同步中...' : '同步 Danbooru 标签',
        child: GestureDetector(
          onTap: widget.isSyncing ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered || widget.isSyncing
                    ? [syncColor.withOpacity(0.2), syncColor.withOpacity(0.1)]
                    : [
                        syncColor.withOpacity(0.08),
                        syncColor.withOpacity(0.04),
                      ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: syncColor.withOpacity(_isHovered ? 0.25 : 0.15),
                  blurRadius: _isHovered ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.isSyncing
                    ? RotationTransition(
                        turns: _animController,
                        child: const Icon(
                          Icons.sync,
                          size: 16,
                          color: syncColor,
                        ),
                      )
                    : const Icon(
                        Icons.cloud_sync_outlined,
                        size: 16,
                        color: syncColor,
                      ),
                const SizedBox(width: 6),
                Text(
                  widget.isSyncing ? '同步中' : 'Danbooru',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: syncColor,
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

/// 重置按钮组件
class _ResetButton extends StatefulWidget {
  const _ResetButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const resetColor = Colors.orange;
    final isEnabled = widget.onPressed != null;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: '重置为默认配置',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered && isEnabled
                    ? [resetColor.withOpacity(0.2), resetColor.withOpacity(0.1)]
                    : [
                        resetColor.withOpacity(0.08),
                        resetColor.withOpacity(0.04),
                      ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: _isHovered && isEnabled
                  ? [
                      BoxShadow(
                        color: resetColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: resetColor.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restart_alt,
                  size: 16,
                  color: isEnabled ? resetColor : resetColor.withOpacity(0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  '重置',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? resetColor : resetColor.withOpacity(0.4),
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

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = widget.onPressed != null;
    final effectiveColor = widget.color ?? colorScheme.onSurfaceVariant;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isHovered && isEnabled
                  ? effectiveColor.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: _isHovered && isEnabled
                  ? [
                      BoxShadow(
                        color: effectiveColor.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedScale(
              scale: _isHovered && isEnabled ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Icon(
                widget.icon,
                size: 20,
                color: isEnabled
                    ? (_isHovered
                        ? effectiveColor
                        : effectiveColor.withOpacity(0.8))
                    : colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 只读模式指示器（紧凑版，用于顶栏）
class _ReadOnlyIndicator extends StatelessWidget {
  const _ReadOnlyIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: '当前预设为默认预设，所有配置项已锁定',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade100.withOpacity(0.15),
              Colors.orange.shade100.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.amber.shade600.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: Colors.amber.shade800,
            ),
            const SizedBox(width: 6),
            Text(
              '只读模式',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
