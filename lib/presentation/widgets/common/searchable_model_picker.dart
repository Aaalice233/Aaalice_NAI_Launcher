import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../themes/theme_extension.dart';
import 'adaptive_title_bar.dart';
import 'heading_semantics.dart';
import 'model_family_icon.dart';

class ModelPickerGroup {
  const ModelPickerGroup({
    required this.id,
    required this.label,
    this.leading,
    this.trailing,
  });

  final String id;
  final String label;
  final Widget? leading;

  /// 组级操作按钮，例如整组添加。
  final Widget? trailing;
}

class ModelPickerOption<T> {
  const ModelPickerOption({
    required this.id,
    required this.value,
    required this.title,
    this.subtitle,
    this.searchTerms = const [],
    this.keyValue,
    this.modelId,
    this.subtitleLeading,
    this.group,
    this.tooltip,
    this.trailing,
  });

  final String id;
  final T value;
  final String title;
  final String? subtitle;
  final List<String> searchTerms;
  final String? keyValue;
  final String? modelId;
  final Widget? subtitleLeading;
  final ModelPickerGroup? group;
  final String? tooltip;

  /// 替换选中勾号的位置，用于展示添加/移除等状态。
  final Widget? trailing;

  String get searchText => [
    title,
    if (subtitle != null) subtitle!,
    if (group != null) group!.label,
    ...searchTerms,
  ].join('\n').toLowerCase();
}

/// 同组选项按首次出现的位置聚拢，组内保持调用方给出的顺序。
List<ModelPickerOption<T>> clusterModelPickerOptions<T>(
  List<ModelPickerOption<T>> options,
) {
  final clusters = <String?, List<ModelPickerOption<T>>>{};
  for (final option in options) {
    (clusters[option.group?.id] ??= []).add(option);
  }
  return [for (final cluster in clusters.values) ...cluster];
}

sealed class _ModelPickerEntry {
  const _ModelPickerEntry();
}

class _ModelPickerGroupEntry extends _ModelPickerEntry {
  const _ModelPickerGroupEntry(this.group);

  final ModelPickerGroup group;
}

class _ModelPickerOptionEntry extends _ModelPickerEntry {
  const _ModelPickerOptionEntry(this.optionIndex);

  final int optionIndex;
}

class SearchableModelPickerField<T> extends StatelessWidget {
  const SearchableModelPickerField({
    super.key,
    required this.pickerTitle,
    required this.searchLabel,
    required this.searchHint,
    required this.clearSearchTooltip,
    required this.emptyMessage,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.decoration,
    this.emptyLabel = '',
    this.selectedLabel,
    this.enabled = true,
    this.keyPrefix = 'model-picker',
  });

  final String pickerTitle;
  final String searchLabel;
  final String searchHint;
  final String clearSearchTooltip;
  final String emptyMessage;
  final List<ModelPickerOption<T>> options;
  final String? selectedId;
  final ValueChanged<T> onSelected;
  final InputDecoration decoration;
  final String emptyLabel;
  final String? selectedLabel;
  final bool enabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final selected = options.cast<ModelPickerOption<T>?>().firstWhere(
      (option) => option?.id == selectedId,
      orElse: () => null,
    );
    final label = selectedLabel ?? selected?.title ?? emptyLabel;
    final interactive = enabled && options.isNotEmpty;
    return Semantics(
      button: true,
      enabled: interactive,
      label: [decoration.labelText, label].whereType<String>().join(': '),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('$keyPrefix-field'),
          borderRadius: BorderRadius.circular(8),
          onTap: interactive ? () => _open(context) : null,
          child: InputDecorator(
            isEmpty: label.isEmpty,
            decoration: decoration.copyWith(enabled: interactive),
            child: Row(
              children: [
                ModelFamilyIcon(
                  modelId: selected?.modelId ?? selectedId ?? label,
                  displayName: label,
                  color: interactive ? null : Theme.of(context).disabledColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: interactive
                        ? null
                        : TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: interactive
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).disabledColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showSearchableModelPicker<T>(
      context: context,
      title: pickerTitle,
      searchLabel: searchLabel,
      searchHint: searchHint,
      clearSearchTooltip: clearSearchTooltip,
      emptyMessage: emptyMessage,
      options: options,
      selectedId: selectedId,
      keyPrefix: keyPrefix,
      headerKeyPrefix: '$keyPrefix-header',
    );
    if (selected != null) onSelected(selected);
  }
}

Future<T?> showSearchableModelPicker<T>({
  required BuildContext context,
  required String title,
  required String searchLabel,
  required String searchHint,
  required String clearSearchTooltip,
  required String emptyMessage,
  required List<ModelPickerOption<T>> options,
  required String? selectedId,
  String keyPrefix = 'model-picker',
  String? headerKeyPrefix,
}) {
  return AdaptivePresenter.showPicker<T>(
    context: context,
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.96,
    width: 620,
    restoreFocus: false,
    builder: (pickerContext, scrollController) => SearchableModelPickerBody<T>(
      title: title,
      searchLabel: searchLabel,
      searchHint: searchHint,
      clearSearchTooltip: clearSearchTooltip,
      emptyMessage: emptyMessage,
      options: options,
      selectedId: selectedId,
      scrollController: scrollController,
      keyPrefix: keyPrefix,
      headerKeyPrefix: headerKeyPrefix,
      onSelected: (option) => Navigator.pop(pickerContext, option.value),
    ),
  );
}

class SearchableModelPickerBody<T> extends StatefulWidget {
  const SearchableModelPickerBody({
    super.key,
    required this.title,
    required this.searchLabel,
    required this.searchHint,
    required this.clearSearchTooltip,
    required this.emptyMessage,
    required this.options,
    required this.selectedId,
    required this.scrollController,
    required this.onSelected,
    this.keyPrefix = 'model-picker',
    this.headerKeyPrefix,
    this.onBack,
    this.selectedIds = const {},
    this.titleBadge,
    this.headerActions = const [],
  });

  final String title;
  final String searchLabel;
  final String searchHint;
  final String clearSearchTooltip;
  final String emptyMessage;
  final List<ModelPickerOption<T>> options;
  final String? selectedId;
  final ScrollController scrollController;
  final ValueChanged<ModelPickerOption<T>> onSelected;
  final String keyPrefix;
  final String? headerKeyPrefix;
  final VoidCallback? onBack;

  /// 多选场景的已选项；与 [selectedId] 同时生效。
  final Set<String> selectedIds;

  /// 标题旁的计数等短标记。
  final String? titleBadge;

  /// 作用于整个列表的批量操作，放在标题栏关闭按钮之前。
  final List<Widget> headerActions;

  @override
  State<SearchableModelPickerBody<T>> createState() =>
      _SearchableModelPickerBodyState<T>();
}

class _SearchableModelPickerBodyState<T>
    extends State<SearchableModelPickerBody<T>> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _query = '';
  var _highlightedIndex = 0;
  late List<ModelPickerOption<T>> _ordered;
  late bool _grouped;

  List<ModelPickerOption<T>> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _ordered;
    return _ordered
        .where((option) => option.searchText.contains(query))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _arrangeOptions();
    _highlightedIndex = _selectedIndex();
  }

  @override
  void didUpdateWidget(covariant SearchableModelPickerBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.options, widget.options)) _arrangeOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // 只有一个分组时标题只会重复页面已知的信息，不显示。
  void _arrangeOptions() {
    _ordered = clusterModelPickerOptions(widget.options);
    _grouped =
        _ordered
            .map((option) => option.group?.id)
            .whereType<String>()
            .toSet()
            .length >
        1;
  }

  int _selectedIndex() {
    final index = _ordered.indexWhere(
      (option) => option.id == widget.selectedId,
    );
    return index < 0 ? 0 : index;
  }

  List<_ModelPickerEntry> _entries(List<ModelPickerOption<T>> filtered) {
    final entries = <_ModelPickerEntry>[];
    String? currentGroup;
    for (var index = 0; index < filtered.length; index++) {
      final group = filtered[index].group;
      if (_grouped && group != null && group.id != currentGroup) {
        entries.add(_ModelPickerGroupEntry(group));
      }
      currentGroup = group?.id;
      entries.add(_ModelPickerOptionEntry(index));
    }
    return entries;
  }

  double _textGrowth(BuildContext context, double perLine) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return (textScale - 1).clamp(0, 3).toDouble() * perLine;
  }

  double _optionExtent(BuildContext context, ModelPickerOption<T> option) {
    final touch = context.interactionPolicy.touchAvailable;
    if (option.subtitle == null) {
      return (touch ? 56.0 : 48.0) + _textGrowth(context, 20);
    }
    return (touch ? 72.0 : 64.0) + _textGrowth(context, 36);
  }

  double _groupExtent(BuildContext context, ModelPickerGroup group) {
    if (group.trailing == null) return 40 + _textGrowth(context, 18);
    final touch = context.interactionPolicy.touchAvailable;
    return (touch ? 56.0 : 48.0) + _textGrowth(context, 18);
  }

  List<double> _entryExtents(
    BuildContext context,
    List<_ModelPickerEntry> entries,
    List<ModelPickerOption<T>> filtered,
  ) => [
    for (final entry in entries)
      switch (entry) {
        _ModelPickerGroupEntry(:final group) => _groupExtent(context, group),
        _ModelPickerOptionEntry(:final optionIndex) => _optionExtent(
          context,
          filtered[optionIndex],
        ),
      },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final entries = _entries(filtered);
    final extents = _entryExtents(context, entries, filtered);
    return Focus(
      onKeyEvent: (_, event) => _handleKey(event, filtered),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(220, constraints.maxHeight * 0.48),
              ),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ModelPickerHeader(
                      title: widget.title,
                      keyPrefix: widget.headerKeyPrefix ?? widget.keyPrefix,
                      onBack: widget.onBack,
                      badge: widget.titleBadge,
                      actions: widget.headerActions,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: TextField(
                        key: ValueKey('${widget.keyPrefix}-search'),
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus:
                            context.interactionPolicy.precisePointerAvailable,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                            _highlightedIndex = 0;
                          });
                          _scrollToHighlight();
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.52),
                          labelText: widget.searchLabel,
                          hintText: widget.searchHint,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  key: ValueKey(
                                    '${widget.keyPrefix}-search-clear',
                                  ),
                                  tooltip: widget.clearSearchTooltip,
                                  onPressed: _clearSearch,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.emptyMessage,
                          key: ValueKey('${widget.keyPrefix}-empty'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('${widget.keyPrefix}-results'),
                      controller: widget.scrollController,
                      itemExtentBuilder: (index, _) =>
                          index < extents.length ? extents[index] : null,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) => switch (entries[index]) {
                        _ModelPickerGroupEntry(:final group) =>
                          _ModelPickerGroupHeader(
                            group: group,
                            headerKey: ValueKey(
                              '${widget.keyPrefix}-group-${group.id}',
                            ),
                          ),
                        _ModelPickerOptionEntry(:final optionIndex) =>
                          _buildOption(filtered, optionIndex),
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(List<ModelPickerOption<T>> filtered, int index) {
    final option = filtered[index];
    return _ModelPickerTile<T>(
      option: option,
      selected:
          option.id == widget.selectedId ||
          widget.selectedIds.contains(option.id),
      highlighted: index == _highlightedIndex,
      itemKey: ValueKey(
        '${widget.keyPrefix}-option-${option.keyValue ?? option.id}',
      ),
      onHover: () {
        if (_highlightedIndex != index) {
          setState(() => _highlightedIndex = index);
        }
      },
      onTap: () => widget.onSelected(option),
    );
  }

  KeyEventResult _handleKey(
    KeyEvent event,
    List<ModelPickerOption<T>> filtered,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_query.isNotEmpty) {
        _clearSearch();
      } else {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }
    if (filtered.isEmpty) return KeyEventResult.ignored;
    int? next;
    if (key == LogicalKeyboardKey.arrowDown) {
      next = (_highlightedIndex + 1).clamp(0, filtered.length - 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      next = (_highlightedIndex - 1).clamp(0, filtered.length - 1);
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = filtered.length - 1;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      widget.onSelected(filtered[_highlightedIndex]);
      return KeyEventResult.handled;
    }
    if (next == null) return KeyEventResult.ignored;
    setState(() => _highlightedIndex = next!);
    _scrollToHighlight();
    return KeyEventResult.handled;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _highlightedIndex = _selectedIndex();
    });
    _searchFocusNode.requestFocus();
    _scrollToHighlight();
  }

  // 分组标题与选项高度不同，只能按条目累加出高亮项的滚动位置。
  double _highlightOffset() {
    final filtered = _filtered;
    final entries = _entries(filtered);
    final extents = _entryExtents(context, entries, filtered);
    var offset = 0.0;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry is _ModelPickerOptionEntry &&
          entry.optionIndex == _highlightedIndex) {
        // 组内第一项连同组标题一起滚入视野。
        final previous = index > 0 ? entries[index - 1] : null;
        return previous is _ModelPickerGroupEntry
            ? offset - extents[index - 1]
            : offset;
      }
      offset += extents[index];
    }
    return offset;
  }

  void _scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      final target = _highlightOffset().clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        widget.scrollController.jumpTo(target);
      } else {
        widget.scrollController.animateTo(
          target,
          duration: Theme.of(context).appTheme.fastDuration,
          curve: Theme.of(context).appTheme.standardCurve,
        );
      }
    });
  }
}

class _ModelPickerHeader extends StatelessWidget {
  const _ModelPickerHeader({
    required this.title,
    required this.keyPrefix,
    this.onBack,
    this.badge,
    this.actions = const [],
  });

  final String title;
  final String keyPrefix;
  final VoidCallback? onBack;
  final String? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
      child: AdaptiveTitleBar(
        minRowHeight: 52,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onBack != null)
              IconButton(
                key: ValueKey('$keyPrefix-back'),
                onPressed: onBack,
                tooltip: localizations.backButtonTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 12),
            Flexible(
              child: _ModelPickerTitle(
                title: title,
                badge: badge,
                keyPrefix: keyPrefix,
              ),
            ),
          ],
        ),
        actions: Wrap(
          key: ValueKey('$keyPrefix-actions'),
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: actions,
        ),
        trailing: IconButton(
          key: ValueKey('$keyPrefix-close'),
          onPressed: () => Navigator.maybePop(context),
          tooltip: localizations.closeButtonTooltip,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _ModelPickerTitle extends StatelessWidget {
  const _ModelPickerTitle({
    required this.title,
    required this.badge,
    required this.keyPrefix,
  });

  final String title;
  final String? badge;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = this.badge;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            key: ValueKey('$keyPrefix-title'),
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          DecoratedBox(
            key: ValueKey('$keyPrefix-title-badge'),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                badge,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModelPickerTile<T> extends StatelessWidget {
  const _ModelPickerTile({
    required this.option,
    required this.selected,
    required this.highlighted,
    required this.itemKey,
    required this.onHover,
    required this.onTap,
  });

  final ModelPickerOption<T> option;
  final bool selected;
  final bool highlighted;
  final Key itemKey;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = option.subtitle;
    final tooltip = option.tooltip;
    final tile = Semantics(
      selected: selected,
      button: true,
      label: [
        option.title,
        if (subtitle != null) subtitle,
        if (option.group != null) option.group!.label,
      ].join(', '),
      child: Material(
        color: highlighted
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: itemKey,
          borderRadius: BorderRadius.circular(6),
          onHover: (hovered) {
            if (hovered) onHover();
          },
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ModelFamilyIcon(
                  modelId: option.modelId ?? option.id,
                  displayName: option.title,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        _ModelPickerSubtitle(
                          text: subtitle,
                          leading: option.subtitleLeading,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                option.trailing ??
                    SizedBox(
                      width: 20,
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip == option.title) return tile;
    return Tooltip(message: tooltip, child: tile);
  }
}

class _ModelPickerSubtitle extends StatelessWidget {
  const _ModelPickerSubtitle({required this.text, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ModelPickerGroupHeader extends StatelessWidget {
  const _ModelPickerGroupHeader({required this.group, required this.headerKey});

  final ModelPickerGroup group;
  final Key headerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HeadingSemantics(
      level: 3,
      child: Padding(
        key: headerKey,
        padding: group.trailing == null
            ? const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4)
            : const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 0),
        child: Row(
          children: [
            if (group.leading != null) ...[
              group.leading!,
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                group.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (group.trailing != null) group.trailing!,
          ],
        ),
      ),
    );
  }
}
