import 'package:flutter/material.dart';

import 'window_size_class.dart';

typedef AdaptivePanelBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Presents secondary controls without forcing one desktop or mobile surface.
class AdaptivePresenter {
  AdaptivePresenter._();

  static Future<T?> showPanel<T>({
    required BuildContext context,
    String? title,
    WidgetBuilder? titleBuilder,
    required AdaptivePanelBuilder builder,
    double initialChildSize = 0.72,
    double minChildSize = 0.38,
    double maxChildSize = 0.94,
    double sideSheetWidth = 440,
  }) {
    assert(title != null || titleBuilder != null);
    final resolvedTitleBuilder =
        titleBuilder ??
        (context) =>
            Text(title!, style: Theme.of(context).textTheme.titleLarge);
    final metrics = context.adaptiveWindow;
    if (metrics.isExpanded) {
      return _showSideSheet<T>(
        context: context,
        titleBuilder: resolvedTitleBuilder,
        builder: builder,
        width: sideSheetWidth,
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      anchorPoint: Offset(metrics.size.width - 1, metrics.size.height - 1),
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      builder: (sheetContext) => AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(sheetContext)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          snap: true,
          snapSizes: [initialChildSize, maxChildSize],
          builder: (context, scrollController) => _PanelSurface(
            titleBuilder: resolvedTitleBuilder,
            scrollController: scrollController,
            child: builder(context, scrollController),
          ),
        ),
      ),
    );
  }

  static Future<T?> _showSideSheet<T>({
    required BuildContext context,
    required WidgetBuilder titleBuilder,
    required AdaptivePanelBuilder builder,
    required double width,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<T>(
      context: context,
      anchorPoint: Offset(MediaQuery.sizeOf(context).width - 1, 0),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => _SideSheetPanel(
        width: width,
        titleBuilder: titleBuilder,
        builder: builder,
      ),
      transitionBuilder: (context, animation, _, child) {
        if (reduceMotion) return child;
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
}

class _SideSheetPanel extends StatefulWidget {
  const _SideSheetPanel({
    required this.width,
    required this.titleBuilder,
    required this.builder,
  });

  final double width;
  final WidgetBuilder titleBuilder;
  final AdaptivePanelBuilder builder;

  @override
  State<_SideSheetPanel> createState() => _SideSheetPanelState();
}

class _SideSheetPanelState extends State<_SideSheetPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: widget.width
                .clamp(320, MediaQuery.sizeOf(context).width * 0.9)
                .toDouble(),
            height: double.infinity,
            child: _PanelSurface(
              titleBuilder: widget.titleBuilder,
              scrollController: _scrollController,
              sideSheet: true,
              child: widget.builder(context, _scrollController),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.titleBuilder,
    required this.scrollController,
    required this.child,
    this.sideSheet = false,
  });

  final WidgetBuilder titleBuilder;
  final ScrollController scrollController;
  final Widget child;
  final bool sideSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: sideSheet
            ? const BorderRadius.horizontal(left: Radius.circular(24))
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          if (!sideSheet)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
              child: Row(
                children: [
                  Expanded(child: titleBuilder(context)),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: !sideSheet,
              child: PrimaryScrollController(
                controller: scrollController,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
