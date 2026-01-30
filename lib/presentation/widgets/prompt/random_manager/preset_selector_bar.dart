import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../common/app_toast.dart';
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  ),
                  const SizedBox(height: 12),
                  // 统计信息 + 操作按钮
                  Row(
                    children: [
                      if (selectedPreset != null)
                        Expanded(
                          child: _StatisticsInfo(preset: selectedPreset),
                        ),
                      _ActionButtons(
                        onCreateNaiV4: () => _createNaiV4Preset(context, ref),
                        onCopy: selectedPreset != null
                            ? () => _copyPreset(context, ref, selectedPreset)
                            : null,
                        onDelete: selectedPreset != null &&
                                !selectedPreset.isDefault
                            ? () => _deletePreset(context, ref, selectedPreset)
                            : null,
                        onGeneratePreview: onGeneratePreview,
                        onImportExport: onImportExport,
                        onSync: () => _syncDanbooru(context, ref),
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
                // 预设选择下拉框
                Flexible(
                  flex: 2,
                  child: _PresetDropdown(
                    presets: presetState.presets,
                    selectedPreset: selectedPreset,
                    onSelected: (preset) {
                      ref
                          .read(randomPresetNotifierProvider.notifier)
                          .selectPreset(preset.id);
                    },
                  ),
                ),
                // 垂直分隔线
                _VerticalDivider(color: colorScheme.primary),
                // 统计信息
                if (selectedPreset != null)
                  Flexible(
                    flex: 3,
                    child: _StatisticsInfo(preset: selectedPreset),
                  ),
                // 垂直分隔线
                _VerticalDivider(color: colorScheme.secondary),
                // 操作按钮组
                _ActionButtons(
                  onCreateNaiV4: () => _createNaiV4Preset(context, ref),
                  onCopy: selectedPreset != null
                      ? () => _copyPreset(context, ref, selectedPreset)
                      : null,
                  onDelete: selectedPreset != null && !selectedPreset.isDefault
                      ? () => _deletePreset(context, ref, selectedPreset)
                      : null,
                  onGeneratePreview: onGeneratePreview,
                  onImportExport: onImportExport,
                  onSync: () => _syncDanbooru(context, ref),
                  isSyncing: syncState.isSyncing,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createNaiV4Preset(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final preset = await notifier.createPreset(
      name: 'NAI V4 官方预设',
      copyFromCurrent: false,
    );
    // 使用默认的 V4 配置重置
    await notifier.updatePreset(preset.resetToDefault());
    await notifier.selectPreset(preset.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已创建 NAI V4 官方预设'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyPreset(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final name = await _showNameDialog(context, '复制预设', '${preset.name} - 副本');
    if (name == null || name.isEmpty) return;

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final newPreset = await notifier.createPreset(name: name);
    await notifier.selectPreset(newPreset.id);
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

  Future<String?> _showNameDialog(
    BuildContext context,
    String title,
    String initialValue,
  ) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _PresetDropdown extends StatelessWidget {
  const _PresetDropdown({
    required this.presets,
    required this.selectedPreset,
    required this.onSelected,
  });

  final List<RandomPreset> presets;
  final RandomPreset? selectedPreset;
  final ValueChanged<RandomPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButton<String>(
        value: selectedPreset?.id,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface),
        items: presets.map((preset) {
          return DropdownMenuItem<String>(
            value: preset.id,
            child: Row(
              children: [
                Icon(
                  preset.isDefault ? Icons.star : Icons.folder_outlined,
                  size: 18,
                  color: preset.isDefault
                      ? Colors.amber
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preset.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            final preset = presets.firstWhere((p) => p.id == id);
            onSelected(preset);
          }
        },
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
    required this.onCreateNaiV4,
    this.onCopy,
    this.onDelete,
    this.onGeneratePreview,
    this.onImportExport,
    this.onSync,
    this.isSyncing = false,
  });

  final VoidCallback onCreateNaiV4;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
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
        // Danbooru 同步按钮
        _SyncButton(
          onPressed: onSync,
          isSyncing: isSyncing,
        ),
        const SizedBox(width: 4),
        // 生成预览按钮
        if (onGeneratePreview != null)
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            tooltip: '生成预览',
            onPressed: onGeneratePreview,
            color: colorScheme.primary,
          ),
        // 一键 NAI V4 按钮
        _ActionButton(
          icon: Icons.auto_fix_high,
          tooltip: '一键创建 NAI V4 预设',
          onPressed: onCreateNaiV4,
          color: Colors.amber,
        ),
        // 复制按钮
        _ActionButton(
          icon: Icons.copy_outlined,
          tooltip: '复制预设',
          onPressed: onCopy,
        ),
        // 删除按钮
        _ActionButton(
          icon: Icons.delete_outline,
          tooltip: '删除预设',
          onPressed: onDelete,
          color: onDelete != null ? Colors.red.shade400 : null,
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
