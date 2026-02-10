import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';

/// Vibe 选择结果
class VibeSelectionResult {
  final List<VibeLibraryEntry> selectedEntries;
  final bool shouldReplace;

  const VibeSelectionResult({
    required this.selectedEntries,
    required this.shouldReplace,
  });
}

/// Vibe 选择器对话框
///
/// 用于从 Vibe 库中选择多个 Vibe 条目
/// 支持多选、搜索、最近使用快速访问
class VibeSelectorDialog extends ConsumerStatefulWidget {
  /// 初始选中的条目 ID
  final Set<String> initialSelectedIds;

  /// 是否显示替换选项
  final bool showReplaceOption;

  /// 标题
  final String? title;

  const VibeSelectorDialog({
    super.key,
    this.initialSelectedIds = const {},
    this.showReplaceOption = true,
    this.title,
  });

  /// 显示对话框的便捷方法
  static Future<VibeSelectionResult?> show({
    required BuildContext context,
    Set<String> initialSelectedIds = const {},
    bool showReplaceOption = true,
    String? title,
  }) {
    return showDialog<VibeSelectionResult>(
      context: context,
      builder: (context) => VibeSelectorDialog(
        initialSelectedIds: initialSelectedIds,
        showReplaceOption: showReplaceOption,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<VibeSelectorDialog> createState() => _VibeSelectorDialogState();
}

class _VibeSelectorDialogState extends ConsumerState<VibeSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<VibeLibraryEntry> _allEntries = [];
  List<VibeLibraryEntry> _recentEntries = [];
  List<VibeLibraryEntry> _filteredEntries = [];
  Set<String> _selectedIds = {};

  bool _isLoading = true;
  bool _isReplaceMode = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final service = ref.read(vibeLibraryStorageServiceProvider);

    try {
      final allEntries = await service.getAllEntries();
      final recentEntries = await service.getRecentEntries(limit: 10);

      setState(() {
        _allEntries = allEntries;
        _recentEntries = recentEntries;
        _filteredEntries = allEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredEntries = _allEntries;
      } else {
        _filteredEntries = _allEntries.where((entry) {
          return entry.name.toLowerCase().contains(_searchQuery) ||
              entry.vibeDisplayName.toLowerCase().contains(_searchQuery) ||
              entry.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
    _searchFocusNode.unfocus();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _filteredEntries.map((e) => e.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedIds.isEmpty) return;

    // 记录使用
    final service = ref.read(vibeLibraryStorageServiceProvider);
    for (final id in _selectedIds) {
      await service.incrementUsedCount(id);
    }

    final selectedEntries =
        _allEntries.where((e) => _selectedIds.contains(e.id)).toList();

    if (mounted) {
      Navigator.of(context).pop(VibeSelectionResult(
        selectedEntries: selectedEntries,
        shouldReplace: _isReplaceMode,
      ),);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              _buildHeader(theme),

              const SizedBox(height: 16),

              // 搜索栏
              _buildSearchBar(theme),

              const SizedBox(height: 16),

              // 内容区域
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_allEntries.isEmpty)
                _buildEmptyState(theme)
              else
                Expanded(
                  child: _buildContent(theme),
                ),

              const SizedBox(height: 16),

              // 底部操作栏
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.style_outlined,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Text(
          widget.title ?? '选择 Vibe',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // 选择计数
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '已选择 ${_selectedIds.length} 项',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: '搜索名称、标签...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 最近使用区域
          if (_searchQuery.isEmpty && _recentEntries.isNotEmpty) ...[
            _buildSectionTitle(theme, '最近使用'),
            const SizedBox(height: 8),
            _buildRecentChips(theme),
            const SizedBox(height: 24),
          ],

          // 全部条目网格
          if (_filteredEntries.isEmpty)
            _buildNoResultsState(theme)
          else ...[
            Row(
              children: [
                Text(
                  _searchQuery.isEmpty ? '全部 Vibe' : '搜索结果',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 快速选择按钮
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('全选'),
                ),
                TextButton.icon(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.deselect, size: 18),
                  label: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildVibeGrid(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentChips(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recentEntries.map((entry) {
        final isSelected = _selectedIds.contains(entry.id);
        return _buildRecentChip(theme, entry, isSelected);
      }).toList(),
    );
  }

  Widget _buildRecentChip(
    ThemeData theme,
    VibeLibraryEntry entry,
    bool isSelected,
  ) {
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _toggleSelection(entry.id),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.hasThumbnail || entry.hasVibeThumbnail)
                _buildThumbnail(
                  entry.thumbnail ?? entry.vibeThumbnail,
                  size: 24,
                )
              else
                Icon(
                  Icons.image,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
              const SizedBox(width: 8),
              Text(
                entry.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVibeGrid(ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        final isSelected = _selectedIds.contains(entry.id);
        return _buildVibeCard(theme, entry, isSelected);
      },
    );
  }

  Widget _buildVibeCard(
    ThemeData theme,
    VibeLibraryEntry entry,
    bool isSelected,
  ) {
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _toggleSelection(entry.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图区域
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: (entry.hasThumbnail || entry.hasVibeThumbnail)
                          ? _buildThumbnail(
                              entry.thumbnail ?? entry.vibeThumbnail,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                    ),
                    // 选择指示器
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    // 收藏标记
                    if (entry.isFavorite)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          Icons.favorite,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              // 信息区域
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '强度 ${(entry.strength * 100).toInt()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.data_usage,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '信息 ${(entry.infoExtracted * 100).toInt()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: entry.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Uint8List? imageData, {
    double size = 48,
    BoxFit fit = BoxFit.cover,
  }) {
    if (imageData == null) {
      return Icon(Icons.image, size: size);
    }

    return Image.memory(
      imageData,
      width: fit == BoxFit.cover ? double.infinity : size,
      height: fit == BoxFit.cover ? double.infinity : size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.broken_image, size: size);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Vibe 库为空',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '先去 Vibe 库添加一些条目吧',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '未找到匹配的 Vibe',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _clearSearch,
            child: const Text('清除搜索'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 模式选择（添加到当前 / 替换）
        if (widget.showReplaceOption && _selectedIds.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('添加到当前'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('替换现有'),
                      icon: Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {_isReplaceMode},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _isReplaceMode = selected.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _selectedIds.isNotEmpty ? _confirmSelection : null,
              icon: const Icon(Icons.check),
              label: Text('确认选择 (${_selectedIds.length})'),
            ),
          ],
        ),
      ],
    );
  }
}
