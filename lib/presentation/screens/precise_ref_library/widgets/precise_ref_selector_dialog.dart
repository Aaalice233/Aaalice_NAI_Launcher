import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/precise_ref_library_provider.dart';
import 'precise_ref_type_filter_chips.dart';

/// 精准参考库条目选择器对话框
///
/// 供生成页「从库导入」使用：网格 + 搜索 + 类型过滤。
/// [multiSelect] 为 false 时点击条目直接返回单个条目。
/// 搜索与类型过滤为对话框内部状态，不影响库页面的过滤条件。
class PreciseRefSelectorDialog extends ConsumerStatefulWidget {
  const PreciseRefSelectorDialog({
    super.key,
    this.multiSelect = true,
    this.scrollController,
  });

  final bool multiSelect;
  final ScrollController? scrollController;

  static Future<List<PreciseRefLibraryEntry>?> show(
    BuildContext context, {
    bool multiSelect = true,
  }) {
    return AdaptivePresenter.showForm<List<PreciseRefLibraryEntry>>(
      context: context,
      titleBuilder: (panelContext) => Text(
        panelContext.l10n.preciseRefLib_selectorTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(panelContext).textTheme.titleLarge,
      ),
      width: 720,
      builder: (panelContext, scrollController) => PreciseRefSelectorDialog(
        multiSelect: multiSelect,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<PreciseRefSelectorDialog> createState() =>
      _PreciseRefSelectorDialogState();
}

class _PreciseRefSelectorDialogState
    extends ConsumerState<PreciseRefSelectorDialog> {
  final Set<String> _selectedIds = {};
  String _query = '';
  PreciseRefType? _typeFilter;
  Timer? _searchDebounceTimer;
  List<PreciseRefLibraryEntry>? _cachedSourceEntries;
  String? _cachedQuery;
  PreciseRefType? _cachedTypeFilter;
  List<PreciseRefLibraryEntry> _cachedVisibleEntries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preciseRefLibraryNotifierProvider.notifier).initialize();
    });
  }

  void _confirm(List<PreciseRefLibraryEntry> entries) {
    final selected = entries.where((e) => _selectedIds.contains(e.id)).toList();
    Navigator.of(context).pop(selected);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _query != value) {
        setState(() => _query = value);
      }
    });
  }

  List<PreciseRefLibraryEntry> _visibleEntries(
    List<PreciseRefLibraryEntry> source,
  ) {
    if (identical(_cachedSourceEntries, source) &&
        _cachedQuery == _query &&
        _cachedTypeFilter == _typeFilter) {
      return _cachedVisibleEntries;
    }

    var entries = source.search(_query);
    final typeFilter = _typeFilter;
    if (typeFilter != null) {
      entries = entries.where((entry) => entry.type == typeFilter).toList();
    }
    _cachedSourceEntries = source;
    _cachedQuery = _query;
    _cachedTypeFilter = typeFilter;
    _cachedVisibleEntries = entries.sortedByCreatedAt();
    return _cachedVisibleEntries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(preciseRefLibraryNotifierProvider);
    final entries = _visibleEntries(state.entries);

    return LayoutBuilder(
      key: const Key('precise-ref-selector-dialog'),
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 340
            ? 2
            : constraints.maxWidth < 500
            ? 3
            : constraints.maxWidth < 680
            ? 4
            : 5;
        return CustomScrollView(
          controller: widget.scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverList.list(
                children: [
                  TextField(
                    key: const Key('precise-ref-selector-search'),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: l10n.preciseRefLib_searchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    key: const Key('precise-ref-selector-type-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: PreciseRefTypeFilterChips(
                      value: _typeFilter,
                      onChanged: (type) => setState(() => _typeFilter = type),
                    ),
                  ),
                ],
              ),
            ),
            if (state.isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    value: MediaQuery.disableAnimationsOf(context)
                        ? 0.72
                        : null,
                  ),
                ),
              )
            else if (state.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorView(state.error!),
              )
            else if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    l10n.preciseRefLib_emptyTouch,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _SelectorItem(
                      entry: entry,
                      selected:
                          widget.multiSelect && _selectedIds.contains(entry.id),
                      onTap: () {
                        if (!widget.multiSelect) {
                          Navigator.of(context).pop([entry]);
                          return;
                        }
                        setState(() {
                          if (!_selectedIds.remove(entry.id)) {
                            _selectedIds.add(entry.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_cancel),
                    ),
                    if (widget.multiSelect)
                      FilledButton(
                        key: const Key('precise-ref-selector-confirm'),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _confirm(state.entries),
                        child: Text(
                          l10n.preciseRefLib_selectorConfirm(
                            _selectedIds.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(String error) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            l10n.preciseRefLib_loadFailed(error),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref
                .read(preciseRefLibraryNotifierProvider.notifier)
                .reload(showLoading: true),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.common_retry),
          ),
        ],
      ),
    );
  }
}

class _SelectorItem extends ConsumerStatefulWidget {
  const _SelectorItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final PreciseRefLibraryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  ConsumerState<_SelectorItem> createState() => _SelectorItemState();
}

class _SelectorItemState extends ConsumerState<_SelectorItem> {
  Uint8List? _thumbnail;
  bool _requested = false;

  @override
  void didUpdateWidget(covariant _SelectorItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _thumbnail = null;
      _requested = false;
    }
  }

  void _loadThumbnail() {
    if (_requested) return;
    _requested = true;
    final id = widget.entry.id;
    final storage = ref.read(preciseRefLibraryStorageServiceProvider);
    // 内存缓存同步命中时直接赋值，让卡片重建后的首帧就有图
    final cached = storage.peekDisplayThumbnail(id);
    if (cached != null && cached.isNotEmpty) {
      _thumbnail = cached;
      return;
    }
    storage.getDisplayThumbnail(id).then((bytes) {
      if (!mounted || widget.entry.id != id) return;
      setState(() => _thumbnail = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    _loadThumbnail();
    final theme = Theme.of(context);
    final entry = widget.entry;

    return InkWell(
      key: Key('precise-ref-selector-item-${entry.id}'),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: widget.selected
              ? Border.all(color: theme.colorScheme.primary, width: 1)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_thumbnail != null)
                    Image.memory(
                      _thumbnail!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  if (widget.selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    entry.type.icon,
                    size: 11,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
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
}
