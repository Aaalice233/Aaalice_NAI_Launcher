import 'package:flutter/material.dart';

import '../../common/elevated_card.dart';

/// 搜索和筛选状态
class SearchFilterState {
  final String searchQuery;
  final Set<String> selectedScopes;
  final bool showEnabledOnly;
  final bool showWithDiyOnly;

  const SearchFilterState({
    this.searchQuery = '',
    this.selectedScopes = const {},
    this.showEnabledOnly = false,
    this.showWithDiyOnly = false,
  });

  SearchFilterState copyWith({
    String? searchQuery,
    Set<String>? selectedScopes,
    bool? showEnabledOnly,
    bool? showWithDiyOnly,
  }) {
    return SearchFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedScopes: selectedScopes ?? this.selectedScopes,
      showEnabledOnly: showEnabledOnly ?? this.showEnabledOnly,
      showWithDiyOnly: showWithDiyOnly ?? this.showWithDiyOnly,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedScopes.isNotEmpty ||
      showEnabledOnly ||
      showWithDiyOnly;
}

/// 搜索筛选栏组件
///
/// 提供搜索和快速筛选功能
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.onFilterChanged,
    this.initialState = const SearchFilterState(),
  });

  final ValueChanged<SearchFilterState> onFilterChanged;
  final SearchFilterState initialState;

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late TextEditingController _searchController;
  late SearchFilterState _state;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _searchController = TextEditingController(text: _state.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateState(SearchFilterState newState) {
    setState(() => _state = newState);
    widget.onFilterChanged(newState);
  }

  void _clearFilters() {
    _searchController.clear();
    _updateState(const SearchFilterState());
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主搜索栏
          Row(
            children: [
              // 搜索输入框
              Expanded(
                child: _SearchInput(
                  controller: _searchController,
                  onChanged: (value) {
                    _updateState(_state.copyWith(searchQuery: value));
                  },
                ),
              ),
              const SizedBox(width: 12),
              // 筛选按钮
              _FilterToggle(
                isExpanded: _isExpanded,
                hasActiveFilters: _state.hasActiveFilters,
                onToggle: () => setState(() => _isExpanded = !_isExpanded),
              ),
              // 清除按钮
              if (_state.hasActiveFilters) ...[
                const SizedBox(width: 8),
                _ClearButton(onClear: _clearFilters),
              ],
            ],
          ),
          // 展开的筛选选项
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _FilterOptions(
                state: _state,
                onStateChanged: _updateState,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索输入框
class _SearchInput extends StatefulWidget {
  const _SearchInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _isFocused
            ? colorScheme.primaryContainer.withOpacity(0.2)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.shadow.withOpacity(0.05),
            blurRadius: _isFocused ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: InputDecoration(
            hintText: '搜索类别或标签组...',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: _isFocused
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

/// 筛选切换按钮
class _FilterToggle extends StatefulWidget {
  const _FilterToggle({
    required this.isExpanded,
    required this.hasActiveFilters,
    required this.onToggle,
  });

  final bool isExpanded;
  final bool hasActiveFilters;
  final VoidCallback onToggle;

  @override
  State<_FilterToggle> createState() => _FilterToggleState();
}

class _FilterToggleState extends State<_FilterToggle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = widget.hasActiveFilters
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isExpanded || _isHovered
                ? activeColor.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color: activeColor,
              ),
              if (widget.hasActiveFilters) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 清除按钮
class _ClearButton extends StatefulWidget {
  const _ClearButton({required this.onClear});

  final VoidCallback onClear;

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClear,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.errorContainer.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.clear_all,
                size: 14,
                color: colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                '清除',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 筛选选项区域
class _FilterOptions extends StatelessWidget {
  const _FilterOptions({
    required this.state,
    required this.onStateChanged,
  });

  final SearchFilterState state;
  final ValueChanged<SearchFilterState> onStateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作用域筛选
          Text(
            '作用域',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: '全局',
                icon: Icons.public,
                isSelected: state.selectedScopes.contains('global'),
                onSelected: (selected) {
                  final scopes = Set<String>.from(state.selectedScopes);
                  if (selected) {
                    scopes.add('global');
                  } else {
                    scopes.remove('global');
                  }
                  onStateChanged(state.copyWith(selectedScopes: scopes));
                },
              ),
              _FilterChip(
                label: '私有',
                icon: Icons.person,
                isSelected: state.selectedScopes.contains('private'),
                onSelected: (selected) {
                  final scopes = Set<String>.from(state.selectedScopes);
                  if (selected) {
                    scopes.add('private');
                  } else {
                    scopes.remove('private');
                  }
                  onStateChanged(state.copyWith(selectedScopes: scopes));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 状态筛选
          Text(
            '状态',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: '仅启用',
                icon: Icons.check_circle_outline,
                isSelected: state.showEnabledOnly,
                onSelected: (selected) {
                  onStateChanged(state.copyWith(showEnabledOnly: selected));
                },
              ),
              _FilterChip(
                label: '有 DIY 能力',
                icon: Icons.auto_awesome,
                isSelected: state.showWithDiyOnly,
                onSelected: (selected) {
                  onStateChanged(state.copyWith(showWithDiyOnly: selected));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 筛选选项芯片
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primary.withOpacity(0.15)
                : _isHovered
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
