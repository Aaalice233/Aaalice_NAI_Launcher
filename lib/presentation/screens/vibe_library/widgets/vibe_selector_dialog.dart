import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../../presentation/providers/vibe_library_provider.dart';
import 'vibe_card.dart';

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
/// 支持多选、搜索、筛选、排序和最近使用快速访问
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

  // 筛选/排序状态字段 (Step 1)
  bool _favoritesOnly = false;
  VibeSourceType? _selectedSourceType;
  final Set<String> _selectedTags = {};
  VibeLibrarySortOrder _sortOrder = VibeLibrarySortOrder.createdAt;
  bool _sortDescending = true;

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

  // 统一的筛选方法 (Step 1)
  void _applyFilters() {
    setState(() {
      var result = _allEntries;

      // 1. 文本搜索
      if (_searchQuery.isNotEmpty) {
        result = result.search(_searchQuery);
      }

      // 2. 收藏过滤
      if (_favoritesOnly) {
        result = result.favorites;
      }

      // 3. 来源类型过滤
      if (_selectedSourceType != null) {
        result =
            result.where((e) => e.sourceType == _selectedSourceType).toList();
      }

      // 4. 标签过滤 (AND 逻辑)
      if (_selectedTags.isNotEmpty) {
        result = result.where((e) {
          return _selectedTags.every((tag) => e.tags.contains(tag));
        }).toList();
      }

      // 5. 排序
      result = _sortEntries(result);

      _filteredEntries = result;
    });
  }

  List<VibeLibraryEntry> _sortEntries(List<VibeLibraryEntry> entries) {
    List<VibeLibraryEntry> sorted;
    switch (_sortOrder) {
      case VibeLibrarySortOrder.createdAt:
        sorted = entries.sortedByCreatedAt();
        break;
      case VibeLibrarySortOrder.lastUsed:
        sorted = entries.sortedByLastUsed();
        break;
      case VibeLibrarySortOrder.usedCount:
        sorted = entries.sortedByUsedCount();
        break;
      case VibeLibrarySortOrder.name:
        sorted = entries.sortedByName();
        break;
    }
    return _sortDescending ? sorted : sorted.reversed.toList();
  }

  void _onSearchChanged(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _applyFilters();
    _searchFocusNode.unfocus();
  }

  void _toggleFavoriteFilter() {
    setState(() {
      _favoritesOnly = !_favoritesOnly;
    });
    _applyFilters();
  }

  void _setSourceType(VibeSourceType? type) {
    setState(() {
      _selectedSourceType = type;
    });
    _applyFilters();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    _applyFilters();
  }

  void _setSortOrder(VibeLibrarySortOrder order) {
    setState(() {
      if (_sortOrder == order) {
        // 点击同一项切换升降序
        _sortDescending = !_sortDescending;
      } else {
        _sortOrder = order;
        _sortDescending = true;
      }
    });
    _applyFilters();
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
        _selectedIds.remove(bundleEntry.id);
      } else {
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

    for (final id in _selectedIds) {
      if (id.contains('#vibe#')) {
        final parts = id.split('#vibe#');
        if (parts.length != 2) continue;

        final bundleId = parts[0];
        final index = int.tryParse(parts[1]) ?? -1;
        if (index < 0) continue;

        final bundleEntry = _allEntries.firstWhere(
          (e) => e.id == bundleId,
          orElse: () => throw StateError('Bundle not found: $bundleId'),
        );

        if (bundleEntry.filePath == null) continue;

        final vibeRef = await fileService.extractVibeFromBundle(
          bundleEntry.filePath!,
          index,
        );
        if (vibeRef == null) continue;

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
        final entry = _allEntries.firstWhere(
          (e) => e.id == id,
          orElse: () => throw StateError('Entry not found: $id'),
        );

        await storageService.incrementUsedCount(id);
        selectedEntries.add(entry);
      }
    }

    if (mounted) {
      Navigator.of(context).pop(
        VibeSelectionResult(
          selectedEntries: selectedEntries,
          shouldReplace: _isReplaceMode,
        ),
      );
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
              _buildHeader(theme),
              const SizedBox(height: 16),
              _buildSearchBar(theme),
              const SizedBox(height: 12),
              _buildFilterToolbar(theme),
              const SizedBox(height: 16),
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
          widget.title ?? context.l10n.vibe_selector_title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              context.l10n.vibeSelectorItemsCount(_selectedIds.length),
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
        hintText: context.l10n.vibeLibrary_searchHint,
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

  // 筛选工具条 (Step 2)
  Widget _buildFilterToolbar(ThemeData theme) {
    final allTags = _allEntries.allTags.toList()..sort();
    final topTags = allTags.take(6).toList();

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // 收藏 FilterChip
          FilterChip(
            selected: _favoritesOnly,
            onSelected: (_) => _toggleFavoriteFilter(),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: _favoritesOnly ? Colors.red : null,
                ),
                const SizedBox(width: 4),
                Text(context.l10n.vibeSelectorFilterFavorites),
              ],
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),

          // 来源类型 PopupMenuButton
          _buildSourceTypeFilter(theme),
          const SizedBox(width: 8),

          // 高频标签 FilterChip 列表
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: topTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: isSelected,
                      onSelected: (_) => _toggleTag(tag),
                      label: Text(tag),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 排序 PopupMenuButton
          _buildSortButton(theme),
          const SizedBox(width: 8),

          // 结果计数
          Text(
            context.l10n.vibeSelectorItemsCount(_filteredEntries.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTypeFilter(ThemeData theme) {
    final colorMap = {
      VibeSourceType.png: Colors.teal,
      VibeSourceType.naiv4vibe: Colors.blue,
      VibeSourceType.naiv4vibebundle: Colors.orange,
      VibeSourceType.rawImage: Colors.purple,
    };

    return PopupMenuButton<VibeSourceType?>(
      offset: const Offset(0, 36),
      onSelected: _setSourceType,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Text(context.l10n.vibeSelectorFilterSourceAll),
              if (_selectedSourceType == null) ...[
                const Spacer(),
                Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...VibeSourceType.values.map((type) {
          final color = colorMap[type] ?? theme.colorScheme.primary;
          return PopupMenuItem(
            value: type,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(type.displayLabel),
                if (_selectedSourceType == type) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                ],
              ],
            ),
          );
        }),
      ],
      child: Chip(
        avatar: _selectedSourceType != null
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorMap[_selectedSourceType],
                  shape: BoxShape.circle,
                ),
              )
            : null,
        label: Text(
          _selectedSourceType?.displayLabel ??
              context.l10n.vibeSelectorFilterSourceAll,
        ),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildSortButton(ThemeData theme) {
    final sortLabelMap = {
      VibeLibrarySortOrder.createdAt: context.l10n.vibeSelectorSortCreated,
      VibeLibrarySortOrder.lastUsed: context.l10n.vibeSelectorSortLastUsed,
      VibeLibrarySortOrder.usedCount: context.l10n.vibeSelectorSortUsedCount,
      VibeLibrarySortOrder.name: context.l10n.vibeSelectorSortName,
    };

    return PopupMenuButton<VibeLibrarySortOrder>(
      offset: const Offset(0, 36),
      onSelected: _setSortOrder,
      itemBuilder: (context) => VibeLibrarySortOrder.values.map((order) {
        final isSelected = _sortOrder == order;
        return PopupMenuItem(
          value: order,
          child: Row(
            children: [
              Text(sortLabelMap[order]!),
              if (isSelected) ...[
                const Spacer(),
                Icon(
                  _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Chip(
        avatar: Icon(
          _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
          size: 14,
        ),
        label: Text(sortLabelMap[_sortOrder]!),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // 内容区域 (Step 3)
  Widget _buildContent(ThemeData theme) {
    if (_filteredEntries.isEmpty) {
      return _buildNoResultsState(theme);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // 减小卡片宽度，增加列数：每列最小 140px，计算可容纳的列数
        const double itemWidth = 140;
        const double spacing = 12;
        final crossAxisCount =
            ((availableWidth + spacing) / (itemWidth + spacing)).floor();
        final columnCount = crossAxisCount.clamp(3, 6); // 最少3列，最多6列

        return CustomScrollView(
          slivers: [
            // 最近使用区域
            if (_searchQuery.isEmpty &&
                _recentEntries.isNotEmpty &&
                !_favoritesOnly &&
                _selectedSourceType == null &&
                _selectedTags.isEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  theme,
                  context.l10n.vibe_selector_recent,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(child: _buildRecentChips(theme)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // "全部 Vibe" 标题行
            SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    _searchQuery.isEmpty
                        ? context.l10n.vibeLibrary_title
                        : context.l10n.search_results,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.select_all, size: 18),
                    label: Text(context.l10n.selectAll),
                  ),
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.deselect, size: 18),
                    label: Text(context.l10n.clearSelection),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // 网格内容 - 按 entry 类型分组
            ..._buildSliverGrids(columnCount),
          ],
        );
      },
    );
  }

  List<Widget> _buildSliverGrids(int columnCount) {
    final slivers = <Widget>[];
    final entries = _filteredEntries;

    // 所有条目（包括 Bundle）放在同一个网格中
    slivers.add(_buildSliverGrid(entries, columnCount));

    // Bundle 展开内容单独添加
    for (final entry in entries) {
      if (entry.isBundle && _expandedBundleIds.contains(entry.id)) {
        slivers.add(_buildBundleExpandedContentSliver(entry));
      }
    }

    return slivers;
  }

  Widget _buildSliverGrid(List<VibeLibraryEntry> entries, int columnCount) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        childAspectRatio: 0.8, // 稍微调整宽高比，让卡片更紧凑
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = _selectedIds.contains(entry.id);

        if (entry.isBundle) {
          final isExpanded = _expandedBundleIds.contains(entry.id);
          return _buildBundleCardCompact(entry, isSelected, isExpanded);
        } else {
          return _buildCompactVibeCard(entry, isSelected);
        }
      },
    );
  }

  // Bundle 展开内容作为 Sliver (Step 5)
  Widget _buildBundleExpandedContentSliver(VibeLibraryEntry entry) {
    final theme = Theme.of(context);
    final previews = entry.bundledVibePreviews ?? [];
    final count = entry.bundledVibeCount;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                  context.l10n.bundle_internalVibes,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      for (var i = 0; i < count; i++) {
                        _selectedIds.add('${entry.id}#vibe#$i');
                      }
                      _selectedIds.remove(entry.id);
                    });
                  },
                  icon: const Icon(Icons.select_all, size: 16),
                  label: Text(context.l10n.selectAll),
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
                final thumbnail =
                    index < previews.length ? previews[index] : null;
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

  // 紧凑全图卡片 - 复用 VibeCard
  Widget _buildCompactVibeCard(VibeLibraryEntry entry, bool isSelected) {
    return VibeCard(
      entry: entry,
      width: 140,
      height: 175, // 0.8 aspect ratio
      isSelected: isSelected,
      showFavoriteIndicator: false, // 选择器中不显示收藏按钮
      onTap: () => _toggleSelection(entry.id),
    );
  }

  // Bundle 紧凑卡片 - 复用 VibeCard 并添加展开按钮
  Widget _buildBundleCardCompact(
    VibeLibraryEntry entry,
    bool isSelected,
    bool isExpanded,
  ) {
    return Stack(
      children: [
        VibeCard(
          entry: entry,
          width: 140,
          height: 175,
          isSelected: isSelected,
          showFavoriteIndicator: false,
          onTap: () => _toggleBundleSelection(entry),
        ),
        // 展开/收起按钮
        Positioned(
          bottom: 4,
          right: 4,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _toggleBundleExpanded(entry.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

// Bundle 内部的 vibe 卡片
  Widget _buildBundledVibeCard(
    ThemeData theme,
    String bundleId,
    int index,
    String name,
    Uint8List? thumbnail,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.none,
      child: InkWell(
        onTap: () => _toggleBundledVibeSelection(bundleId, index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: isSelected ? 2.5 : 1,
            ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图区域
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.2),
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
                              errorBuilder: (_, __, ___) =>
                                  _buildBundledPlaceholder(theme),
                            )
                          : _buildBundledPlaceholder(theme),
                      // 选中遮罩
                      if (isSelected)
                        Container(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                      // 选中标记
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      theme.colorScheme.shadow.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 名称区域
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: theme.colorScheme.primary,
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

  Widget _buildBundledPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: theme.colorScheme.outline,
        ),
      ),
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
              context.l10n.vibeLibrary_empty,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.vibeLibrary_emptyHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
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
          Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            context.l10n.search_noResults,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _clearSearch();
              setState(() {
                _favoritesOnly = false;
                _selectedSourceType = null;
                _selectedTags.clear();
              });
              _applyFilters();
            },
            child: Text(context.l10n.clearFilters),
          ),
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
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(context.l10n.addToCurrent),
                      icon: const Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(context.l10n.replaceExisting),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {_isReplaceMode},
                  onSelectionChanged: (selected) =>
                      setState(() => _isReplaceMode = selected.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
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
              label: Text(
                '${context.l10n.confirmSelection} (${_selectedIds.length})',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
