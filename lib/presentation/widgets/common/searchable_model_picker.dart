import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../themes/theme_extension.dart';

class ModelPickerOption<T> {
  const ModelPickerOption({
    required this.id,
    required this.value,
    required this.title,
    required this.subtitle,
    this.searchTerms = const [],
    this.keyValue,
  });

  final String id;
  final T value;
  final String title;
  final String subtitle;
  final List<String> searchTerms;
  final String? keyValue;

  String get searchText =>
      [title, subtitle, ...searchTerms].join('\n').toLowerCase();
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

  List<ModelPickerOption<T>> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options
        .where((option) => option.searchText.contains(query))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _highlightedIndex = _selectedIndex();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int _selectedIndex() {
    final index = widget.options.indexWhere(
      (option) => option.id == widget.selectedId,
    );
    return index < 0 ? 0 : index;
  }

  double _rowExtent(BuildContext context) {
    final base = context.interactionPolicy.touchAvailable ? 72.0 : 64.0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return base + (textScale - 1).clamp(0, 3).toDouble() * 36;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final rowExtent = _rowExtent(context);
    return Focus(
      onKeyEvent: (_, event) => _handleKey(event, filtered, rowExtent),
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
                          _scrollToHighlight(rowExtent);
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
                      itemExtent: rowExtent,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        return _ModelPickerTile<T>(
                          option: option,
                          selected: option.id == widget.selectedId,
                          highlighted: index == _highlightedIndex,
                          itemKey: ValueKey(
                            '${widget.keyPrefix}-option-'
                            '${option.keyValue ?? option.id}',
                          ),
                          onHover: () {
                            if (_highlightedIndex != index) {
                              setState(() => _highlightedIndex = index);
                            }
                          },
                          onTap: () => widget.onSelected(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKey(
    KeyEvent event,
    List<ModelPickerOption<T>> filtered,
    double rowExtent,
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
    _scrollToHighlight(rowExtent);
    return KeyEventResult.handled;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _highlightedIndex = _selectedIndex();
    });
    _searchFocusNode.requestFocus();
    _scrollToHighlight(_rowExtent(context));
  }

  void _scrollToHighlight(double rowExtent) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      final target = (_highlightedIndex * rowExtent).clamp(
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
  });

  final String title;
  final String keyPrefix;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 4),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                key: ValueKey('$keyPrefix-back'),
                onPressed: onBack,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                key: ValueKey('$keyPrefix-title'),
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: ValueKey('$keyPrefix-close'),
              onPressed: () => Navigator.maybePop(context),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
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
    return Semantics(
      selected: selected,
      button: true,
      label: '${option.title}, ${option.subtitle}',
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
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
