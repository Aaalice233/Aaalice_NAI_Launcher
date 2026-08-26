import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// Enhanced pagination bar with complete navigation features
/// 增强分页栏，包含完整的导航功能
///
/// Features:
/// - First/Last page navigation
/// - Page number buttons with ellipsis
/// - Items per page selector
/// - Page jump input
/// - Total count and range display
class PaginationBar extends StatefulWidget {
  final int currentPage; // 0-based
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onItemsPerPageChanged;
  final List<int> itemsPerPageOptions;
  final bool showItemsPerPage;
  final bool showTotalInfo;
  final bool compact;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.totalItems = 0,
    this.itemsPerPage = 50,
    this.onItemsPerPageChanged,
    this.itemsPerPageOptions = const [20, 50, 100, 200],
    this.showItemsPerPage = true,
    this.showTotalInfo = true,
    this.compact = false,
  });

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = (widget.currentPage + 1).toString();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _submitPage() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      _cancelEditing();
      return;
    }

    final parsed = int.tryParse(input);
    if (parsed == null) {
      _cancelEditing();
      return;
    }

    int targetPage = parsed - 1;
    if (targetPage < 0) targetPage = 0;
    if (targetPage >= widget.totalPages) targetPage = widget.totalPages - 1;

    setState(() {
      _isEditing = false;
    });

    if (targetPage != widget.currentPage) {
      widget.onPageChanged(targetPage);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return _buildNarrowLayout(theme, colorScheme);
          }
          return widget.compact
              ? _buildCompactLayout(theme, colorScheme)
              : _buildFullLayout(theme, colorScheme);
        },
      ),
    );
  }

  Widget _buildFullLayout(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Total info
        if (widget.showTotalInfo && widget.totalItems > 0)
          _buildTotalInfo(theme, colorScheme),

        const Spacer(),

        // Page navigation
        _buildPageNavigation(theme, colorScheme),

        const Spacer(),

        // Items per page selector
        if (widget.showItemsPerPage && widget.onItemsPerPageChanged != null)
          _buildItemsPerPageSelector(theme, colorScheme),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_buildPageNavigation(theme, colorScheme)],
    );
  }

  Widget _buildNarrowLayout(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildNavButton(
          icon: Icons.chevron_left,
          tooltip: context.l10n.pagination_previousPage,
          onPressed: widget.currentPage > 0
              ? () => widget.onPageChanged(widget.currentPage - 1)
              : null,
        ),
        const SizedBox(width: 8),
        _buildCurrentPageJump(theme, colorScheme),
        const SizedBox(width: 8),
        _buildNavButton(
          icon: Icons.chevron_right,
          tooltip: context.l10n.pagination_nextPage,
          onPressed: widget.currentPage < widget.totalPages - 1
              ? () => widget.onPageChanged(widget.currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildCurrentPageJump(ThemeData theme, ColorScheme colorScheme) {
    final extent = PlatformCapabilities.current.hasTouchInput ? 48.0 : 32.0;
    if (_isEditing) {
      return SizedBox(width: 72, height: extent, child: _buildJumpInput(theme));
    }

    return Tooltip(
      message: context.l10n.pagination_jumpToPage,
      child: InkWell(
        onTap: widget.totalPages > 1 ? _startEditing : null,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 72, minHeight: extent),
          child: Center(
            child: Text(
              '${widget.currentPage + 1} / ${widget.totalPages}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalInfo(ThemeData theme, ColorScheme colorScheme) {
    final startItem = widget.currentPage * widget.itemsPerPage + 1;
    final endItem = ((widget.currentPage + 1) * widget.itemsPerPage).clamp(
      0,
      widget.totalItems,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.image_outlined,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          '$startItem-$endItem',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          ' / ${widget.totalItems}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPageNavigation(ThemeData theme, ColorScheme colorScheme) {
    final l10n = context.l10n;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First page
        _buildNavButton(
          icon: Icons.first_page,
          tooltip: l10n.pagination_firstPage,
          onPressed: widget.currentPage > 0
              ? () => widget.onPageChanged(0)
              : null,
        ),

        // Previous page
        _buildNavButton(
          icon: Icons.chevron_left,
          tooltip: l10n.pagination_previousPage,
          onPressed: widget.currentPage > 0
              ? () => widget.onPageChanged(widget.currentPage - 1)
              : null,
        ),

        const SizedBox(width: 4),

        // Page numbers
        ..._buildPageNumbers(theme, colorScheme),

        const SizedBox(width: 4),

        // Next page
        _buildNavButton(
          icon: Icons.chevron_right,
          tooltip: l10n.pagination_nextPage,
          onPressed: widget.currentPage < widget.totalPages - 1
              ? () => widget.onPageChanged(widget.currentPage + 1)
              : null,
        ),

        // Last page
        _buildNavButton(
          icon: Icons.last_page,
          tooltip: l10n.pagination_lastPage,
          onPressed: widget.currentPage < widget.totalPages - 1
              ? () => widget.onPageChanged(widget.totalPages - 1)
              : null,
        ),

        const SizedBox(width: 8),

        // Jump to page
        _buildJumpToPage(theme, colorScheme),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    final extent = PlatformCapabilities.current.hasTouchInput ? 48.0 : 32.0;
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: PlatformCapabilities.current.hasTouchInput
          ? VisualDensity.standard
          : VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: BoxConstraints(minWidth: extent, minHeight: extent),
    );
  }

  List<Widget> _buildPageNumbers(ThemeData theme, ColorScheme colorScheme) {
    final List<Widget> buttons = [];
    final int current = widget.currentPage;
    final int total = widget.totalPages;

    if (total <= 7) {
      // Show all pages
      for (int i = 0; i < total; i++) {
        buttons.add(_buildPageButton(i, theme, colorScheme));
      }
    } else {
      // Show with ellipsis
      // Always show first page
      buttons.add(_buildPageButton(0, theme, colorScheme));

      if (current > 3) {
        buttons.add(_buildEllipsis(theme));
      }

      // Show pages around current
      int start = (current - 1).clamp(1, total - 4);
      int end = (current + 1).clamp(3, total - 2);

      if (current <= 3) {
        end = 4;
      }
      if (current >= total - 4) {
        start = total - 5;
      }

      for (int i = start; i <= end; i++) {
        buttons.add(_buildPageButton(i, theme, colorScheme));
      }

      if (current < total - 4) {
        buttons.add(_buildEllipsis(theme));
      }

      // Always show last page
      buttons.add(_buildPageButton(total - 1, theme, colorScheme));
    }

    return buttons;
  }

  Widget _buildPageButton(int page, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = page == widget.currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isSelected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: isSelected ? null : () => widget.onPageChanged(page),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: BoxConstraints(
              minWidth: PlatformCapabilities.current.hasTouchInput ? 48 : 32,
              minHeight: PlatformCapabilities.current.hasTouchInput ? 48 : 32,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${page + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildJumpToPage(ThemeData theme, ColorScheme colorScheme) {
    final touchInput = PlatformCapabilities.current.hasTouchInput;
    final extent = touchInput ? 48.0 : 32.0;
    if (_isEditing) {
      return SizedBox(width: 60, height: extent, child: _buildJumpInput(theme));
    }

    return Tooltip(
      message: context.l10n.pagination_jumpToPage,
      child: TextButton.icon(
        onPressed: widget.totalPages > 1 ? _startEditing : null,
        icon: const Icon(Icons.arrow_forward, size: 14),
        label: Text(context.l10n.pagination_jump),
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.bodySmall,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size(0, extent),
          tapTargetSize: touchInput
              ? MaterialTapTargetSize.padded
              : MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildJumpInput(ThemeData theme) {
    return ThemedInput(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      onSubmitted: (_) => _submitPage(),
    );
  }

  Widget _buildItemsPerPageSelector(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.pagination_itemsPerPage,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: widget.itemsPerPage,
              isDense: true,
              items: widget.itemsPerPageOptions.map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text('$count', style: theme.textTheme.bodyMedium),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null && widget.onItemsPerPageChanged != null) {
                  widget.onItemsPerPageChanged!(value);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          context.l10n.pagination_itemUnit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
