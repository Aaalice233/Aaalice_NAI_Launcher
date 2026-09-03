import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
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
  final bool enabled;
  final bool loading;
  final IconData? totalIcon;
  final String? totalItemsLabel;
  final bool tonalCard;

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
    this.enabled = true,
    this.loading = false,
    this.totalIcon,
    this.totalItemsLabel,
    this.tonalCard = false,
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
  void didUpdateWidget(PaginationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canInteract && _isEditing) {
      _isEditing = false;
      _focusNode.unfocus();
    }
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

  bool get _canInteract => widget.enabled && !widget.loading;

  List<int> get _effectiveItemsPerPageOptions {
    final options = {
      ...widget.itemsPerPageOptions,
      widget.itemsPerPage,
    }.toList()..sort();
    return options;
  }

  void _startEditing() {
    if (!_canInteract) return;
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
    if (!_canInteract || widget.totalPages <= 0) {
      _cancelEditing();
      return;
    }
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

    return Semantics(
      container: true,
      enabled: _canInteract,
      liveRegion: widget.loading,
      label: widget.loading ? context.l10n.common_loading : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final bar = Container(
            height: narrow && !largeText ? 48 : null,
            constraints: narrow
                ? const BoxConstraints(minHeight: 48)
                : const BoxConstraints(),
            padding: EdgeInsets.symmetric(
              vertical: narrow ? 0 : 10,
              horizontal: narrow ? 4 : 16,
            ),
            decoration: BoxDecoration(
              color: widget.tonalCard
                  ? controlSurfaceColor(colorScheme)
                  : isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              border: widget.tonalCard
                  ? null
                  : Border(
                      top: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
              borderRadius: widget.tonalCard ? BorderRadius.circular(10) : null,
            ),
            child: narrow
                ? _buildNarrowLayout(
                    theme,
                    colorScheme,
                    veryNarrow: constraints.maxWidth < 400,
                  )
                : widget.compact
                ? _buildCompactLayout(theme, colorScheme)
                : constraints.maxWidth < 1600 || largeText
                ? _buildMediumLayout(theme, colorScheme)
                : _buildFullLayout(theme, colorScheme),
          );
          if (!widget.tonalCard) return bar;
          return Padding(padding: const EdgeInsets.all(8), child: bar);
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

  Widget _buildMediumLayout(ThemeData theme, ColorScheme colorScheme) {
    final showLeadingInfo = widget.showTotalInfo && widget.totalItems > 0;
    final showTrailingSelector =
        widget.showItemsPerPage && widget.onItemsPerPageChanged != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLeadingInfo || showTrailingSelector) ...[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showLeadingInfo) _buildTotalInfo(theme, colorScheme),
              if (showTrailingSelector)
                _buildItemsPerPageSelector(theme, colorScheme),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildPageNavigation(theme, colorScheme),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    ThemeData theme,
    ColorScheme colorScheme, {
    required bool veryNarrow,
  }) {
    final itemCountLabel =
        widget.totalItemsLabel ??
        context.l10n.onlineGallery_imageCount(widget.totalItems.toString());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left,
            tooltip: context.l10n.pagination_previousPage,
            onPressed: widget.currentPage > 0
                ? () => widget.onPageChanged(widget.currentPage - 1)
                : null,
          ),
          const SizedBox(width: 4),
          _buildCurrentPageJump(theme, colorScheme),
          const SizedBox(width: 4),
          _buildNavButton(
            icon: Icons.chevron_right,
            tooltip: context.l10n.pagination_nextPage,
            onPressed: widget.currentPage < widget.totalPages - 1
                ? () => widget.onPageChanged(widget.currentPage + 1)
                : null,
          ),
          SizedBox(width: veryNarrow ? 12 : 24),
          if (veryNarrow)
            Tooltip(
              message: itemCountLabel,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.totalIcon ?? Icons.photo_library_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.totalItems.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              itemCountLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (widget.showItemsPerPage &&
              widget.onItemsPerPageChanged != null) ...[
            const SizedBox(width: 4),
            SizedBox.square(
              dimension: context.interactionPolicy.minimumControlExtent,
              child: PopupMenuButton<int>(
                key: const ValueKey('pagination-narrow-items-per-page'),
                enabled: _canInteract,
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size.square(context.interactionPolicy.minimumControlExtent),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: context.l10n.pagination_itemsPerPage,
                icon: const Icon(Icons.tune_rounded, size: 18),
                onSelected: widget.onItemsPerPageChanged,
                itemBuilder: (context) => [
                  for (final count in _effectiveItemsPerPageOptions)
                    CheckedPopupMenuItem<int>(
                      value: count,
                      checked: count == widget.itemsPerPage,
                      child: Text('$count ${context.l10n.pagination_itemUnit}'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentPageJump(ThemeData theme, ColorScheme colorScheme) {
    if (_isEditing) {
      return SizedBox(
        width:
            80 +
            (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2) * 20,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: context.interactionPolicy.minimumControlExtent,
          ),
          child: _buildJumpInput(theme),
        ),
      );
    }

    return Tooltip(
      message: context.l10n.pagination_jumpToPage,
      child: InkWell(
        onTap: widget.totalPages > 1 && _canInteract ? _startEditing : null,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: context.interactionPolicy.minimumControlExtent,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.onlineGallery_pageN(
                      (widget.currentPage + 1).toString(),
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.loading) ...[
                    const SizedBox(width: 6),
                    SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.72
                            : null,
                      ),
                    ),
                  ] else if (widget.totalPages > 1) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit,
                      size: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ],
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
          widget.totalIcon ?? Icons.image_outlined,
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
    final interactionPolicy = context.interactionPolicy;
    final extent = interactionPolicy.minimumControlExtent;
    return IconButton(
      icon: Icon(icon, size: 20),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.square(extent)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      tooltip: tooltip,
      onPressed: _canInteract ? onPressed : null,
      visualDensity: interactionPolicy.prefersTouchPresentation
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
      child: Semantics(
        button: true,
        selected: isSelected,
        enabled: _canInteract && !isSelected,
        label: context.l10n.onlineGallery_pageN('${page + 1}'),
        child: Material(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: isSelected || !_canInteract
                ? null
                : () => widget.onPageChanged(page),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              constraints: BoxConstraints(
                minWidth: context.interactionPolicy.minimumControlExtent,
                minHeight: context.interactionPolicy.minimumControlExtent,
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
    final interactionPolicy = context.interactionPolicy;
    final extent = interactionPolicy.minimumControlExtent;
    if (_isEditing) {
      return SizedBox(
        width:
            60 +
            (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2) * 20,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: extent),
          child: _buildJumpInput(theme),
        ),
      );
    }

    return Tooltip(
      message: context.l10n.pagination_jumpToPage,
      child: TextButton.icon(
        onPressed: widget.totalPages > 1 && _canInteract ? _startEditing : null,
        icon: widget.loading
            ? SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
                ),
              )
            : const Icon(Icons.arrow_forward, size: 14),
        label: Text(context.l10n.pagination_jump),
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.bodySmall,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size(0, extent),
          tapTargetSize: interactionPolicy.shouldExposeTouchAlternatives
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
      enabled: _canInteract,
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
              items: _effectiveItemsPerPageOptions.map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text('$count', style: theme.textTheme.bodyMedium),
                );
              }).toList(),
              onChanged: !_canInteract
                  ? null
                  : (value) {
                      if (value != null &&
                          widget.onItemsPerPageChanged != null) {
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
