import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommandItem {
  final String id;
  final String label;
  final IconData? icon;
  final String category;
  final VoidCallback? action;

  CommandItem({
    required this.id,
    required this.label,
    this.icon,
    this.category = 'General',
    this.action,
  });
}

class CommandPalette extends StatefulWidget {
  final List<CommandItem> commands;
  final void Function(CommandItem) onSelect;

  const CommandPalette({
    super.key,
    required this.commands,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<CommandItem> commands,
    required void Function(CommandItem) onSelect,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: const Alignment(0, -0.6), // Top 20%
          child: Material(
            type: MaterialType.transparency,
            child: CommandPalette(
              commands: commands,
              onSelect: onSelect,
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();

  List<CommandItem> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    _searchController.addListener(_onSearchChanged);

    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

    // Auto-focus the input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
        _scrollToSelected();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + _filteredCommands.length) %
            _filteredCommands.length;
        _scrollToSelected();
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_filteredCommands.isNotEmpty) {
        _selectItem(_filteredCommands[_selectedIndex]);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      if (query.isEmpty) {
        _filteredCommands = widget.commands;
      } else {
        _filteredCommands = _fuzzySearch(query, widget.commands);
      }
      _selectedIndex = 0; // Reset selection on search
    });
  }

  List<CommandItem> _fuzzySearch(String query, List<CommandItem> items) {
    query = query.toLowerCase();

    // Calculate score for each item
    final scoredItems = items
        .map((item) {
          final text = item.label.toLowerCase();
          int score = 0;
          int queryIdx = 0;
          int textIdx = 0;

          // Simple subsequence matching
          while (queryIdx < query.length && textIdx < text.length) {
            if (query[queryIdx] == text[textIdx]) {
              score += 10;
              // Bonus for consecutive matches
              if (textIdx > 0 &&
                  queryIdx > 0 &&
                  query[queryIdx - 1] == text[textIdx - 1]) {
                score += 5;
              }
              // Bonus for start of word (simplified)
              if (textIdx == 0 || text[textIdx - 1] == ' ') {
                score += 10;
              }
              queryIdx++;
            }
            textIdx++;
          }

          // Only include if full query is found as subsequence
          final isMatch = queryIdx == query.length;
          return MapEntry(item, isMatch ? score : -1);
        })
        .where((e) => e.value > -1)
        .toList();

    // Sort by score descending
    scoredItems.sort((a, b) => b.value.compareTo(a.value));

    return scoredItems.map((e) => e.key).toList();
  }

  void _scrollToSelected() {
    if (_filteredCommands.isEmpty) return;

    // Approximate item height - this is a simple estimation
    // For production, referencing GlobalKeys or using Scrollable.ensureVisible is better
    const itemHeight = 56.0;
    final offset = _selectedIndex * itemHeight;

    if (offset < _scrollController.offset) {
      _scrollController.jumpTo(offset);
    } else if (offset + itemHeight >
        _scrollController.offset +
            _scrollController.position.viewportDimension) {
      _scrollController.jumpTo(
        offset + itemHeight - _scrollController.position.viewportDimension,
      );
    }
  }

  void _selectItem(CommandItem item) {
    widget.onSelect(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 400),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 32,
              spreadRadius: -4,
              offset: Offset.zero,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                  .withOpacity(0.95),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Input
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Type a command or search...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.5),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                            cursorColor: colorScheme.primary,
                            onSubmitted: (_) {
                              if (_filteredCommands.isNotEmpty) {
                                _selectItem(_filteredCommands[_selectedIndex]);
                              }
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme
                                .surfaceContainerHighest, // Changed from surfaceContainerHighest
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ESC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Command List
                  Flexible(
                    child: _filteredCommands.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No commands found',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: _filteredCommands.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) {
                              final item = _filteredCommands[index];
                              final isSelected = index == _selectedIndex;

                              return GestureDetector(
                                onTap: () => _selectItem(item),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary.withOpacity(0.2)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon ?? Icons.code,
                                        size: 20,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.label,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? colorScheme.onSurface
                                                    : colorScheme.onSurface
                                                        .withOpacity(0.9),
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            if (item.category.isNotEmpty &&
                                                item.category != 'General')
                                              Text(
                                                item.category,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.keyboard_return,
                                          size: 16,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      color: colorScheme.surfaceContainerHighest
                          .withOpacity(0.5), // Changed from surfaceContainer
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildKeyHint(context, '↑↓'),
                            const SizedBox(width: 8),
                            Text(
                              'to navigate',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildKeyHint(context, '↵'),
                            const SizedBox(width: 8),
                            Text(
                              'to select',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyHint(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme
            .surfaceContainerHighest, // Changed from surfaceContainerHighest
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
