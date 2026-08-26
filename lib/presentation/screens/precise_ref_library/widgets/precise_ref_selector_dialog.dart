import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../providers/precise_ref_library_provider.dart';
import 'precise_ref_type_filter_chips.dart';

/// 精准参考库条目选择器对话框
///
/// 供生成页「从库导入」使用：网格 + 搜索 + 类型过滤。
/// [multiSelect] 为 false 时点击条目直接返回单个条目。
/// 搜索与类型过滤为对话框内部状态，不影响库页面的过滤条件。
class PreciseRefSelectorDialog extends ConsumerStatefulWidget {
  const PreciseRefSelectorDialog({super.key, this.multiSelect = true});

  final bool multiSelect;

  static Future<List<PreciseRefLibraryEntry>?> show(
    BuildContext context, {
    bool multiSelect = true,
  }) {
    return showDialog<List<PreciseRefLibraryEntry>>(
      context: context,
      builder: (context) => PreciseRefSelectorDialog(multiSelect: multiSelect),
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

    return AlertDialog(
      title: Text(l10n.preciseRefLib_selectorTitle),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const Key('precise-ref-selector-search'),
              decoration: InputDecoration(
                hintText: l10n.preciseRefLib_searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: PreciseRefTypeFilterChips(
                value: _typeFilter,
                onChanged: (type) => setState(() => _typeFilter = type),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? _buildErrorView(state.error!)
                  : entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.preciseRefLib_empty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
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
                              widget.multiSelect &&
                              _selectedIds.contains(entry.id),
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
          ],
        ),
      ),
      actions: [
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
              l10n.preciseRefLib_selectorConfirm(_selectedIds.length),
            ),
          ),
      ],
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
    ref
        .read(preciseRefLibraryStorageServiceProvider)
        .getDisplayThumbnail(id)
        .then((bytes) {
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
