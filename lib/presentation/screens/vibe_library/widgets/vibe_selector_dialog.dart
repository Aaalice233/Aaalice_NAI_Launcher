import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
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
  final Set<String> _expandedBundleIds = {};

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

  void _toggleBundleExpanded(String bundleId) {
    setState(() {
      if (_expandedBundleIds.contains(bundleId)) {
        _expandedBundleIds.remove(bundleId);
      } else {
        _expandedBundleIds.add(bundleId);
      }
    });
  }

  void _toggleBundleSelection(VibeLibraryEntry bundleEntry) {
    setState(() {
      if (_selectedIds.contains(bundleEntry.id)) {
        // 取消选择整个 bundle
        _selectedIds.remove(bundleEntry.id);
      } else {
        // 选择整个 bundle
        _selectedIds.add(bundleEntry.id);
      }
    });
  }

  void _toggleBundledVibeSelection(String bundleId, int index) {
    final bundledVibeId = '$bundleId#vibe#$index';
    setState(() {
      if (_selectedIds.contains(bundledVibeId)) {
        _selectedIds.remove(bundledVibeId);
      } else {
        _selectedIds.add(bundledVibeId);
      }
    });
  }

  bool _isBundledVibeSelected(String bundleId, int index) {
    return _selectedIds.contains('$bundleId#vibe#$index');
  }

  bool _isBundlePartiallySelected(VibeLibraryEntry bundleEntry) {
    if (_selectedIds.contains(bundleEntry.id)) return false;
    for (var i = 0; i < bundleEntry.bundledVibeCount; i++) {
      if (_selectedIds.contains('${bundleEntry.id}#vibe#$i')) {
        return true;
      }
    }
    return false;
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

    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    final fileService = VibeFileStorageService();

    final selectedEntries = <VibeLibraryEntry>[];

    // 处理普通条目和 bundle
    for (final id in _selectedIds) {
      if (id.contains('#vibe#')) {
        // Bundle 内部的 vibe，格式: bundleId#vibe#index
        final parts = id.split('#vibe#');
        if (parts.length != 2) continue;

        final bundleId = parts[0];
        final index = int.tryParse(parts[1]) ?? -1;
        if (index < 0) continue;

        // 查找 bundle 条目
        final bundleEntry = _allEntries.firstWhere(
          (e) => e.id == bundleId,
          orElse: () => throw StateError('Bundle not found: $bundleId'),
        );

        if (bundleEntry.filePath == null) continue;

        // 从 bundle 提取 vibe
        final vibeRef = await fileService.extractVibeFromBundle(
          bundleEntry.filePath!,
          index,
        );
        if (vibeRef == null) continue;

        // 创建临时 entry（不保存到 Hive）
        final name = index < (bundleEntry.bundledVibeNames?.length ?? 0)
            ? bundleEntry.bundledVibeNames![index]
            : '${bundleEntry.displayName} - ${index + 1}';

        selectedEntries.add(
          VibeLibraryEntry.create(
            name: name,
            vibeDisplayName: vibeRef.displayName,
            vibeEncoding: vibeRef.vibeEncoding,
            thumbnail: vibeRef.thumbnail,
            sourceType: vibeRef.sourceType,
          ),
        );
      } else {
        // 普通条目或整个 bundle
        final entry = _allEntries.firstWhere(
          (e) => e.id == id,
          orElse: () => throw StateError('Entry not found: $id'),
        );

        // 记录使用
        await storageService.incrementUsedCount(id);
        selectedEntries.add(entry);
      }
    }

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    entry.thumbnail ?? entry.vibeThumbnail!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, size: 18);
                    },
                  ),
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        final isExpanded = _expandedBundleIds.contains(entry.id);

        if (entry.isBundle) {
          return _buildBundleItem(theme, entry, isExpanded);
        } else {
          final isSelected = _selectedIds.contains(entry.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildVibeCard(theme, entry, isSelected),
          );
        }
      },
    );
  }

  Widget _buildBundleItem(
    ThemeData theme,
    VibeLibraryEntry entry,
    bool isExpanded,
  ) {
    final isBundleSelected = _selectedIds.contains(entry.id);
    final isPartiallySelected = _isBundlePartiallySelected(entry);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bundle 卡片
        _buildBundleCard(
          theme,
          entry,
          isBundleSelected,
          isPartiallySelected,
          isExpanded,
        ),
        // 展开时的内部 vibes 网格
        if (isExpanded)
          _buildBundleExpandedContent(theme, entry),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBundleCard(
    ThemeData theme,
    VibeLibraryEntry entry,
    bool isSelected,
    bool isPartiallySelected,
    bool isExpanded,
  ) {
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : isPartiallySelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.15)
              : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _toggleBundleSelection(entry),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : isPartiallySelected
                    ? Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        width: 1,
                      )
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图区域
              Stack(
                children: [
                  // 预览缩略图
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    child: _buildBundlePreview(entry),
                  ),
                  // 选择指示器
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 40,
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
                  // 部分选择指示器
                  if (isPartiallySelected && !isSelected)
                    Positioned(
                      top: 8,
                      right: 40,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.indeterminate_check_box,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  // Bundle 徽章
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers,
                            size: 12,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.bundledVibeCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 展开/收起按钮
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => _toggleBundleExpanded(entry.id),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.expand_more,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
                    Text(
                      'Bundle',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
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

  Widget _buildBundlePreview(VibeLibraryEntry entry) {
    final previews = entry.bundledVibePreviews ?? [];
    final count = previews.length;

    if (count == 0) {
      return Center(
        child: Icon(
          Icons.layers_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
      );
    }

    // 显示最多4个缩略图，层叠效果
    return Stack(
      alignment: Alignment.center,
      children: [
        if (count >= 4)
          Positioned(
            left: 0,
            child: _buildStackedThumbnail(previews[3], 0.5, -0.08),
          ),
        if (count >= 3)
          Positioned(
            left: 16,
            child: _buildStackedThumbnail(previews[2], 0.65, -0.05),
          ),
        if (count >= 2)
          Positioned(
            left: 32,
            child: _buildStackedThumbnail(previews[1], 0.8, -0.02),
          ),
        Positioned(
          left: 48,
          child: _buildStackedThumbnail(previews[0], 1.0, 0),
        ),
      ],
    );
  }

  Widget _buildStackedThumbnail(
    Uint8List thumbnail,
    double opacity,
    double rotation,
  ) {
    return Transform.rotate(
      angle: rotation,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 24),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBundleExpandedContent(
    ThemeData theme,
    VibeLibraryEntry entry,
  ) {
    final previews = entry.bundledVibePreviews ?? [];
    final count = entry.bundledVibeCount;

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.grid_view,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                '内部 Vibes',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // 选择所有内部 vibes
                  setState(() {
                    for (var i = 0; i < count; i++) {
                      _selectedIds.add('${entry.id}#vibe#$i');
                    }
                    // 如果 bundle 被选中，取消 bundle 的选择
                    _selectedIds.remove(entry.id);
                  });
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('全选'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: count,
            itemBuilder: (context, index) {
              final isSelected = _isBundledVibeSelected(entry.id, index);
              final thumbnail = index < previews.length ? previews[index] : null;
              final vibeNames = entry.bundledVibeNames ?? [];
              final name = index < vibeNames.length
                  ? vibeNames[index]
                  : 'Vibe ${index + 1}';

              return _buildBundledVibeCard(
                theme,
                entry.id,
                index,
                name,
                thumbnail,
                isSelected,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenericVibeCard({
    required ThemeData theme,
    required String name,
    required Uint8List? thumbnail,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isBundleItem,
    double? strength,
    double? infoExtracted,
    bool isFavorite = false,
    List<String> tags = const [],
  }) {
    final borderRadius = isBundleItem ? 8.0 : 12.0;
    final backgroundColor = isSelected
        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
        : isBundleItem
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : isBundleItem
                    ? Border.all(color: theme.colorScheme.outline.withOpacity(0.2))
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
                      child: thumbnail != null
                          ? Image.memory(
                              thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(theme, isBundleItem),
                            )
                          : _buildPlaceholder(theme, isBundleItem),
                    ),
                    if (isSelected)
                      Positioned(
                        top: isBundleItem ? 4 : 8,
                        right: isBundleItem ? 4 : 8,
                        child: Container(
                          padding: EdgeInsets.all(isBundleItem ? 2 : 4),
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                          child: Icon(Icons.check, size: isBundleItem ? 12 : 16, color: theme.colorScheme.onPrimary),
                        ),
                      ),
                    if (!isBundleItem && isFavorite)
                      const Positioned(top: 8, left: 8, child: Icon(Icons.favorite, size: 16, color: Colors.red)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isBundleItem ? 6 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: isBundleItem ? 10 : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (!isBundleItem) ...[
                      const SizedBox(height: 4),
                      _buildStatsRow(theme, strength, infoExtracted),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildTags(theme, tags),
                      ],
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

  Widget _buildPlaceholder(ThemeData theme, bool isBundleItem) => Container(
    color: theme.colorScheme.surfaceContainerHigh,
    child: Icon(Icons.image_outlined, size: isBundleItem ? 24 : 48, color: theme.colorScheme.outline),
  );

  Widget _buildStatsRow(ThemeData theme, double? strength, double? infoExtracted) => Row(
    children: [
      Icon(Icons.tune, size: 12, color: theme.colorScheme.outline),
      const SizedBox(width: 4),
      Text('强度 ${((strength ?? 0) * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(width: 8),
      Icon(Icons.data_usage, size: 12, color: theme.colorScheme.outline),
      const SizedBox(width: 4),
      Text('信息 ${((infoExtracted ?? 0) * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
    ],
  );

  Widget _buildTags(ThemeData theme, List<String> tags) => Wrap(
    spacing: 4,
    children: tags.take(3).map((tag) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    ),
  ).toList(),
  );

  Widget _buildBundledVibeCard(
    ThemeData theme,
    String bundleId,
    int index,
    String name,
    Uint8List? thumbnail,
    bool isSelected,
  ) {
    return _buildGenericVibeCard(
      theme: theme,
      name: name,
      thumbnail: thumbnail,
      isSelected: isSelected,
      onTap: () => _toggleBundledVibeSelection(bundleId, index),
      isBundleItem: true,
    );
  }

  Widget _buildVibeCard(
    ThemeData theme,
    VibeLibraryEntry entry,
    bool isSelected,
  ) {
    return _buildGenericVibeCard(
      theme: theme,
      name: entry.displayName,
      thumbnail: entry.thumbnail ?? entry.vibeThumbnail,
      isSelected: isSelected,
      onTap: () => _toggleSelection(entry.id),
      isBundleItem: false,
      strength: entry.strength,
      infoExtracted: entry.infoExtracted,
      isFavorite: entry.isFavorite,
      tags: entry.tags,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('Vibe 库为空', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text('先去 Vibe 库添加一些条目吧', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
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
          Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('未找到匹配的 Vibe', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          TextButton(onPressed: _clearSearch, child: const Text('清除搜索')),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showReplaceOption && _selectedIds.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('添加到当前'), icon: Icon(Icons.add)),
                    ButtonSegment(value: true, label: Text('替换现有'), icon: Icon(Icons.swap_horiz)),
                  ],
                  selected: {_isReplaceMode},
                  onSelectionChanged: (selected) => setState(() => _isReplaceMode = selected.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.common_cancel)),
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
