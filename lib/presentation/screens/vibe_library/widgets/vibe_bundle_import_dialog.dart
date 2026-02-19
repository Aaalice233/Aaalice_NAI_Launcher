import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';

/// Bundle 导入选项枚举
enum BundleImportOption {
  /// 作为整体导入（默认）
  keepAsBundle,

  /// 拆分为独立条目
  split,

  /// 只导入选中的 vibes
  importSelected,
}

/// Bundle 导入结果
class BundleImportResult {
  /// 导入选项
  final BundleImportOption option;

  /// 选中的 vibe 索引列表（importSelected 时使用）
  final List<int>? selectedIndices;

  const BundleImportResult({
    required this.option,
    this.selectedIndices,
  });
}

/// Vibe Bundle 导入选项对话框
///
/// 用于在导入 Bundle 文件时让用户选择导入方式：
/// - 作为整体导入：保持 bundle 结构，作为一个条目导入
/// - 拆分为独立条目：将 bundle 中的每个 vibe 作为独立条目导入
/// - 选择要导入的 vibes：只导入用户选中的部分 vibe
class VibeBundleImportDialog extends StatefulWidget {
  /// Bundle 文件名
  final String bundleName;

  /// Bundle 内部 vibe 名称列表
  final List<String> vibeNames;

  /// Bundle 内部 vibe 缩略图列表（可选）
  final List<Uint8List>? vibeThumbnails;

  /// Bundle 创建时间（可选）
  final DateTime? createdAt;

  /// Bundle 中的 vibe 数量
  int get vibeCount => vibeNames.length;

  const VibeBundleImportDialog({
    super.key,
    required this.bundleName,
    required this.vibeNames,
    this.vibeThumbnails,
    this.createdAt,
  });

  /// 显示对话框的便捷方法
  static Future<BundleImportResult?> show({
    required BuildContext context,
    required String bundleName,
    required List<String> vibeNames,
    List<Uint8List>? vibeThumbnails,
    DateTime? createdAt,
  }) {
    return showDialog<BundleImportResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeBundleImportDialog(
        bundleName: bundleName,
        vibeNames: vibeNames,
        vibeThumbnails: vibeThumbnails,
        createdAt: createdAt,
      ),
    );
  }

  @override
  State<VibeBundleImportDialog> createState() => _VibeBundleImportDialogState();
}

class _VibeBundleImportDialogState extends State<VibeBundleImportDialog> {
  /// 当前选中的导入选项
  BundleImportOption _selectedOption = BundleImportOption.keepAsBundle;

  /// 选中的 vibe 索引集合（importSelected 时使用）
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // 默认全选所有 vibes
    _selectedIndices.addAll(
      List.generate(widget.vibeCount, (index) => index),
    );
    AppLogger.d(
      'VibeBundleImportDialog 初始化，bundle: ${widget.bundleName}, '
      'vibes: ${widget.vibeCount}',
      'VibeBundleImportDialog',
    );
  }

  /// 确认导入
  void _confirm() {
    final result = BundleImportResult(
      option: _selectedOption,
      selectedIndices: _selectedOption == BundleImportOption.importSelected
          ? (_selectedIndices.toList()..sort())
          : null,
    );

    AppLogger.i(
      'Bundle 导入确认: option=${_selectedOption.name}, '
      'selectedCount=${result.selectedIndices?.length ?? "N/A"}',
      'VibeBundleImportDialog',
    );

    Navigator.of(context).pop(result);
  }

  /// 取消导入
  void _cancel() {
    AppLogger.i('Bundle 导入取消', 'VibeBundleImportDialog');
    Navigator.of(context).pop();
  }

  /// 切换 vibe 选择状态
  void _toggleVibeSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
    AppLogger.d(
      'Vibe 选择改变: index=$index, selected=${_selectedIndices.contains(index)}',
      'VibeBundleImportDialog',
    );
  }

  /// 全选所有 vibes
  void _selectAll() {
    setState(() {
      _selectedIndices.addAll(
        List.generate(widget.vibeCount, (index) => index),
      );
    });
  }

  /// 取消全选
  void _selectNone() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          minWidth: 400,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              _buildHeader(theme),
              const SizedBox(height: 20),

              // Bundle 信息
              _buildBundleInfo(theme),
              const SizedBox(height: 20),

              // 导入选项
              _buildImportOptions(theme),

              // 选择列表（仅在选择"选择要导入的 vibes"时显示）
              if (_selectedOption == BundleImportOption.importSelected) ...[
                const SizedBox(height: 16),
                _buildSelectionHeader(theme),
                const SizedBox(height: 12),
                Flexible(
                  child: _buildVibeSelectionList(theme),
                ),
              ],

              const SizedBox(height: 20),

              // 底部按钮
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.folder_zip,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '导入 Vibe Bundle',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
          tooltip: '取消',
        ),
      ],
    );
  }

  /// 构建 Bundle 信息卡片
  Widget _buildBundleInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.bundleName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                theme,
                icon: Icons.waves,
                label: '${widget.vibeCount} 个 Vibe',
              ),
              const SizedBox(width: 12),
              if (widget.createdAt != null)
                _buildInfoChip(
                  theme,
                  icon: Icons.calendar_today,
                  label: _formatDate(widget.createdAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息标签
  Widget _buildInfoChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 构建导入选项区域
  Widget _buildImportOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择导入方式',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          theme,
          option: BundleImportOption.keepAsBundle,
          icon: Icons.folder_zip,
          title: '作为整体导入',
          subtitle: '保持 bundle 结构，作为一个条目导入库中',
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          theme,
          option: BundleImportOption.split,
          icon: Icons.splitscreen,
          title: '拆分为独立条目',
          subtitle: '将每个 vibe 作为独立的库条目导入',
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          theme,
          option: BundleImportOption.importSelected,
          icon: Icons.checklist,
          title: '选择要导入的 vibes',
          subtitle: '只导入您选中的部分 vibe',
        ),
      ],
    );
  }

  /// 构建选项卡片
  Widget _buildOptionTile(
    ThemeData theme, {
    required BundleImportOption option,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedOption == option;

    return InkWell(
      onTap: () => setState(() => _selectedOption = option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        child: Row(
          children: [
            Radio<BundleImportOption>(
              value: option,
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() => _selectedOption = value!);
              },
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建选择列表头部
  Widget _buildSelectionHeader(ThemeData theme) {
    final allSelected = _selectedIndices.length == widget.vibeCount;
    final noneSelected = _selectedIndices.isEmpty;

    return Row(
      children: [
        Text(
          '选择要导入的 Vibes',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: allSelected ? null : _selectAll,
          child: const Text('全选'),
        ),
        TextButton(
          onPressed: noneSelected ? null : _selectNone,
          child: const Text('全不选'),
        ),
      ],
    );
  }

  /// 构建 Vibe 选择列表（网格布局）
  Widget _buildVibeSelectionList(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算列数：每列最小宽度 100，最大 4 列
        const double minItemWidth = 100;
        final int crossAxisCount =
            (constraints.maxWidth / minItemWidth).floor().clamp(2, 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: widget.vibeCount,
          itemBuilder: (context, index) {
            final vibeName = widget.vibeNames[index];
            final thumbnail = widget.vibeThumbnails != null &&
                    index < widget.vibeThumbnails!.length
                ? widget.vibeThumbnails![index]
                : null;
            final isSelected = _selectedIndices.contains(index);

            return _buildVibeGridCard(
              theme,
              index: index,
              name: vibeName,
              thumbnail: thumbnail,
              isSelected: isSelected,
            );
          },
        );
      },
    );
  }

  /// 构建单个 Vibe 网格卡片
  Widget _buildVibeGridCard(
    ThemeData theme, {
    required int index,
    required String name,
    Uint8List? thumbnail,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleVibeSelection(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            // 选中时使用主色边框，未选中时使用柔和边框
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withOpacity(0.6),
              width: isSelected ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            // 添加渐变背景增加层次感
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.25)
                : theme.colorScheme.surface,
            // 选中时添加阴影增加立体感
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 缩略图区域
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surfaceContainerHighest,
                    // 内部边框区分图片区域
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 缩略图
                      thumbnail != null
                          ? Image.memory(
                              thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 28,
                                    color: theme.colorScheme.outline,
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                Icons.image,
                                size: 28,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                      // 选中时的遮罩
                      if (isSelected)
                        Container(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                        ),
                      // 选中标记（右上角勾选图标）
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 信息区域
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${index + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.7),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme) {
    final bool canConfirm = _selectedOption != BundleImportOption.importSelected ||
        _selectedIndices.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 选中数量提示（仅在选择模式下显示）
        if (_selectedOption == BundleImportOption.importSelected) ...[
          Text(
            '已选择 ${_selectedIndices.length}/${widget.vibeCount} 个',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
        ],
        // 取消按钮
        TextButton(
          onPressed: _cancel,
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        // 确认按钮
        FilledButton.icon(
          onPressed: canConfirm ? _confirm : null,
          icon: const Icon(Icons.download),
          label: const Text('导入'),
        ),
      ],
    );
  }
}
