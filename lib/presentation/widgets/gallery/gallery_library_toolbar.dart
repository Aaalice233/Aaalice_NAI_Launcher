import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../common/compact_icon_button.dart';
import '../common/input_surface_container.dart';
import 'gallery_sidebar.dart';

/// Shared responsive toolbar for collection-style library pages.
///
/// Pages declare their title, search and action modules. This widget owns the
/// layout transition so page implementations cannot drift between desktop and
/// compact presentations.
class GalleryLibraryToolbar extends StatelessWidget {
  const GalleryLibraryToolbar({
    super.key,
    required this.title,
    required this.search,
    this.count,
    this.actions = const [],
    this.primaryAction,
    this.supplementary,
    this.compactBreakpoint = 1050,
  });

  final Widget title;
  final Widget? count;
  final Widget search;
  final List<Widget> actions;
  final Widget? primaryAction;
  final Widget? supplementary;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    return GalleryCollectionToolbarSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final compact =
              constraints.maxWidth / textScale < compactBreakpoint ||
              textScale > 1.5;
          return _GalleryLibraryToolbarScope(
            compact: compact,
            child: compact ? _buildCompact(context) : _buildDesktop(),
          );
        },
      ),
    );
  }

  Widget _buildDesktop() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const ValueKey('gallery-library-toolbar-desktop'),
          children: [
            title,
            if (count != null) ...[const SizedBox(width: 8), count!],
            const SizedBox(width: GalleryCollectionChrome.toolbarGroupGap),
            Expanded(child: search),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 8),
              ..._spaced(actions, 6),
            ],
            if (primaryAction != null) ...[
              const SizedBox(width: 8),
              primaryAction!,
            ],
          ],
        ),
        if (supplementary != null) ...[
          const SizedBox(height: 8),
          supplementary!,
        ],
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final minimumExtent = context.interactionPolicy.minimumControlExtent;
    return Column(
      key: const ValueKey('gallery-library-toolbar-compact'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(child: title),
            if (count != null) ...[const SizedBox(width: 8), count!],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: search),
            if (primaryAction != null) ...[
              const SizedBox(width: 8),
              primaryAction!,
            ],
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _HorizontalActionStrip(
            minimumExtent: minimumExtent,
            children: _spaced(actions, 4),
          ),
        ],
        if (supplementary != null) ...[
          const SizedBox(height: 8),
          supplementary!,
        ],
      ],
    );
  }

  List<Widget> _spaced(List<Widget> children, double spacing) => [
    for (var index = 0; index < children.length; index++) ...[
      if (index > 0) SizedBox(width: spacing),
      children[index],
    ],
  ];
}

class _HorizontalActionStrip extends StatefulWidget {
  const _HorizontalActionStrip({
    required this.minimumExtent,
    required this.children,
  });

  final double minimumExtent;
  final List<Widget> children;

  @override
  State<_HorizontalActionStrip> createState() => _HorizontalActionStripState();
}

class _HorizontalActionStripState extends State<_HorizontalActionStrip> {
  final ScrollController _controller = ScrollController();
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateOverflowIndicator);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateOverflowIndicator(),
    );
  }

  @override
  void didUpdateWidget(_HorizontalActionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateOverflowIndicator(),
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateOverflowIndicator)
      ..dispose();
    super.dispose();
  }

  void _updateOverflowIndicator() {
    if (!mounted || !_controller.hasClients) return;
    final canScrollForward =
        _controller.position.maxScrollExtent - _controller.offset > 1;
    if (canScrollForward != _canScrollForward) {
      setState(() => _canScrollForward = canScrollForward);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.minimumExtent),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          SingleChildScrollView(
            key: const ValueKey('gallery-library-toolbar-actions'),
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(right: _canScrollForward ? 32 : 0),
            child: Row(children: widget.children),
          ),
          if (_canScrollForward)
            IgnorePointer(
              child: Container(
                key: const ValueKey('gallery-library-toolbar-scroll-hint'),
                width: 32,
                height: widget.minimumExtent,
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surface.withValues(alpha: 0),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GalleryLibraryCountBadge extends StatelessWidget {
  const GalleryLibraryCountBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Shared search surface. Autocomplete-enabled pages can wrap this widget with
/// their existing autocomplete coordinator without duplicating its chrome.
class GalleryLibrarySearchField extends StatelessWidget {
  const GalleryLibrarySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.focusNode,
    this.onClear,
    this.onSubmitted,
    this.clearTooltip,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = _GalleryLibraryToolbarScope.maybeCompactOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final touch = context.interactionPolicy.shouldExposeTouchAlternatives;
    final expandedHeight = 48.0 + (textScale - 1).clamp(0.0, 2.0) * 8.0;
    final height = compact || touch ? expandedHeight : 36.0;
    return InputSurfaceContainer(
      height: height,
      borderRadius: compact || touch ? 16 : 18,
      focusedBorderColor: theme.colorScheme.primary.withValues(alpha: 0.38),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          style: theme.textTheme.bodyMedium,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            filled: false,
            hintText: hintText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: clearTooltip,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      controller.clear();
                      (onClear ?? () => onChanged(''))();
                    },
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

class GalleryLibraryAction extends StatelessWidget {
  const GalleryLibraryAction({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.onPressed,
    this.isActive = false,
    this.isDanger = false,
    this.isLoading = false,
    this.shortcutId,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isDanger;
  final bool isLoading;
  final String? shortcutId;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: context.interactionPolicy.minimumControlExtent,
      ),
      child: CompactIconButton(
        icon: icon,
        label: label,
        tooltip: tooltip,
        onPressed: onPressed,
        isActive: isActive,
        isDanger: isDanger,
        isLoading: isLoading,
        shortcutId: shortcutId,
      ),
    );
  }
}

class GalleryLibraryPrimaryAction extends StatelessWidget {
  const GalleryLibraryPrimaryAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final minimumExtent = context.interactionPolicy.minimumControlExtent;
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: Size(0, minimumExtent),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

@immutable
class GalleryLibrarySortOption<T> {
  const GalleryLibrarySortOption({required this.value, required this.label});

  final T value;
  final String label;
}

class GalleryLibrarySortMenu<T> extends StatelessWidget {
  const GalleryLibrarySortMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.descending,
  });

  final String label;
  final T value;
  final List<GalleryLibrarySortOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool? descending;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: () => onSelected(option.value),
            trailingIcon: option.value == value
                ? Icon(
                    descending == null
                        ? Icons.check
                        : descending!
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 16,
                  )
                : null,
            child: Text(option.label),
          ),
      ],
      builder: (context, controller, _) => GalleryLibraryAction(
        icon: Icons.sort,
        label: label,
        tooltip: label,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class GalleryLibraryViewToggle extends StatelessWidget {
  const GalleryLibraryViewToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) => GalleryLibraryAction(
    icon: icon,
    label: label,
    tooltip: tooltip,
    onPressed: onPressed,
    isActive: isActive,
  );
}

class _GalleryLibraryToolbarScope extends InheritedWidget {
  const _GalleryLibraryToolbarScope({
    required this.compact,
    required super.child,
  });

  final bool compact;

  static bool maybeCompactOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_GalleryLibraryToolbarScope>()
          ?.compact ??
      false;

  @override
  bool updateShouldNotify(_GalleryLibraryToolbarScope oldWidget) =>
      compact != oldWidget.compact;
}
