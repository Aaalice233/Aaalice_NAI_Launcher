import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../themes/core/layered_surface_style.dart';
import '../themes/theme_extension.dart';
import 'window_size_class.dart';

/// Builds a panel body with the presenter-owned scroll controller.
///
/// Centered forms receive a loose height constraint so short content can size
/// naturally. Scrollable short forms must set `shrinkWrap: true`; long,
/// virtualized collections can consume the bounded viewport instead.
typedef AdaptivePanelBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Presents secondary controls without forcing one desktop or mobile surface.
class AdaptivePresenter {
  AdaptivePresenter._();

  static const double defaultDialogWidth = 560;

  /// Presents dialog-style editing flows in a bottom sheet below the expanded
  /// breakpoint and in a bounded, centered surface on wider panes.
  static Future<T?> showForm<T>({
    required BuildContext context,
    String? title,
    WidgetBuilder? titleBuilder,
    required AdaptivePanelBuilder builder,
    double? dialogWidth,
    double? maxCenteredHeight,
    bool barrierDismissible = true,
    bool requestFocus = true,
    bool restoreFocus = true,
    bool showHeader = true,
  }) async {
    assert(!showHeader || title != null || titleBuilder != null);
    final metrics = context.adaptiveWindow;
    final resolvedTitleBuilder =
        titleBuilder ??
        (context) =>
            Text(title!, style: Theme.of(context).textTheme.titleLarge);
    final previousFocus = restoreFocus
        ? FocusManager.instance.primaryFocus
        : null;
    if (metrics.isExpandedOrWider) {
      final result = await _showCenteredForm<T>(
        context: context,
        titleBuilder: resolvedTitleBuilder,
        builder: builder,
        width: dialogWidth ?? defaultDialogWidth,
        maxHeight: maxCenteredHeight,
        barrierDismissible: barrierDismissible,
        requestFocus: requestFocus,
        showHeader: showHeader,
      );
      if (restoreFocus && context.mounted && previousFocus?.context != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (previousFocus!.context != null && previousFocus.canRequestFocus) {
            previousFocus.requestFocus();
          }
        });
      }
      return result;
    }
    final result = await showPanel<T>(
      context: context,
      titleBuilder: resolvedTitleBuilder,
      builder: builder,
      initialChildSize: 1,
      minChildSize: 0.5,
      maxChildSize: 1,
      dialogWidth: dialogWidth,
      barrierDismissible: barrierDismissible,
      allowDragDismissal: barrierDismissible,
      requestFocus: requestFocus,
      restoreFocus: false,
      showHeader: showHeader,
    );
    if (restoreFocus && context.mounted && previousFocus?.context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previousFocus!.context != null && previousFocus.canRequestFocus) {
          previousFocus.requestFocus();
        }
      });
    }
    return result;
  }

  /// Presents a searchable picker using a bottom sheet below the expanded
  /// breakpoint and a geometrically stable, centered surface on wider panes.
  static Future<T?> showPicker<T>({
    required BuildContext context,
    required AdaptivePanelBuilder builder,
    double initialChildSize = 0.9,
    double minChildSize = 0.5,
    double maxChildSize = 0.96,
    double? width,
    double? maxCenteredHeight,
    bool barrierDismissible = true,
    bool requestFocus = true,
    bool restoreFocus = true,
  }) async {
    final metrics = context.adaptiveWindow;
    if (!metrics.isExpandedOrWider) {
      final motion = Theme.of(context).appTheme;
      return showPanel<T>(
        context: context,
        title: '',
        builder: builder,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        dialogWidth: width,
        barrierDismissible: barrierDismissible,
        requestFocus: requestFocus,
        restoreFocus: restoreFocus,
        showHeader: false,
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : AnimationStyle(
                duration: motion.normalDuration,
                reverseDuration: motion.fastDuration,
              ),
      );
    }

    final previousFocus = restoreFocus
        ? FocusManager.instance.primaryFocus
        : null;
    final result = await _showCenteredForm<T>(
      context: context,
      titleBuilder: (_) => const SizedBox.shrink(),
      builder: builder,
      width: width ?? defaultDialogWidth,
      maxHeight: maxCenteredHeight,
      barrierDismissible: barrierDismissible,
      requestFocus: requestFocus,
      showHeader: false,
    );
    if (restoreFocus && context.mounted && previousFocus?.context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previousFocus!.context != null && previousFocus.canRequestFocus) {
          previousFocus.requestFocus();
        }
      });
    }
    return result;
  }

  /// Presents auxiliary content as a bottom sheet on compact panes and as an
  /// independent, centered dialog everywhere else.
  static Future<T?> showPanel<T>({
    required BuildContext context,
    String? title,
    WidgetBuilder? titleBuilder,
    required AdaptivePanelBuilder builder,
    double initialChildSize = 0.72,
    double minChildSize = 0.38,
    double maxChildSize = 0.94,
    double? dialogWidth,
    bool barrierDismissible = true,
    bool allowDragDismissal = true,
    bool requestFocus = true,
    bool restoreFocus = true,
    bool showHeader = true,
    AnimationStyle? sheetAnimationStyle,
  }) async {
    assert(!showHeader || title != null || titleBuilder != null);
    final resolvedTitleBuilder =
        titleBuilder ??
        (context) =>
            Text(title!, style: Theme.of(context).textTheme.titleLarge);
    final metrics = context.adaptiveWindow;
    final previousFocus = restoreFocus
        ? FocusManager.instance.primaryFocus
        : null;
    final Future<T?> presentation;
    if (metrics.isExpandedOrWider) {
      presentation = _showCenteredForm<T>(
        context: context,
        titleBuilder: resolvedTitleBuilder,
        builder: builder,
        width: dialogWidth ?? defaultDialogWidth,
        barrierDismissible: barrierDismissible,
        requestFocus: requestFocus,
        showHeader: showHeader,
      );
    } else {
      final motion = Theme.of(context).appTheme;
      presentation = showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        anchorPoint: Offset(metrics.size.width - 1, metrics.size.height - 1),
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: barrierDismissible,
        enableDrag: allowDragDismissal,
        requestFocus: requestFocus,
        backgroundColor: Colors.transparent,
        barrierColor: Theme.of(
          context,
        ).colorScheme.scrim.withValues(alpha: 0.4),
        sheetAnimationStyle: sheetAnimationStyle,
        builder: (sheetContext) => AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(sheetContext)
              ? Duration.zero
              : motion.fastDuration,
          curve: motion.standardCurve,
          padding: EdgeInsets.only(
            bottom: _activeRouteViewInsetBottom(sheetContext),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            snap: true,
            snapSizes: initialChildSize == maxChildSize
                ? [maxChildSize]
                : [initialChildSize, maxChildSize],
            builder: (context, scrollController) => _PanelSurface(
              titleBuilder: resolvedTitleBuilder,
              scrollController: scrollController,
              showHeader: showHeader,
              child: builder(context, scrollController),
            ),
          ),
        ),
      );
    }

    final result = await presentation;
    if (restoreFocus && context.mounted && previousFocus?.context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previousFocus!.context != null && previousFocus.canRequestFocus) {
          previousFocus.requestFocus();
        }
      });
    }
    return result;
  }

  static Future<T?> _showCenteredForm<T>({
    required BuildContext context,
    required WidgetBuilder titleBuilder,
    required AdaptivePanelBuilder builder,
    required double width,
    required bool barrierDismissible,
    required bool requestFocus,
    required bool showHeader,
    double? maxHeight,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Theme.of(context).appTheme;
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierDismissible
          ? MaterialLocalizations.of(context).modalBarrierDismissLabel
          : null,
      requestFocus: requestFocus,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.36),
      transitionDuration: reduceMotion ? Duration.zero : motion.fastDuration,
      pageBuilder: (dialogContext, _, __) => _CenteredFormPanel(
        width: width,
        titleBuilder: titleBuilder,
        builder: builder,
        showHeader: showHeader,
        maxHeight: maxHeight,
      ),
      transitionBuilder: (context, animation, _, child) {
        if (reduceMotion) return child;
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

class _CenteredFormPanel extends StatefulWidget {
  const _CenteredFormPanel({
    required this.width,
    required this.titleBuilder,
    required this.builder,
    required this.showHeader,
    this.maxHeight,
  });

  final double width;
  final WidgetBuilder titleBuilder;
  final AdaptivePanelBuilder builder;
  final bool showHeader;
  final double? maxHeight;

  @override
  State<_CenteredFormPanel> createState() => _CenteredFormPanelState();
}

class _CenteredFormPanelState extends State<_CenteredFormPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = Theme.of(context).appTheme;
    final size = MediaQuery.sizeOf(context);
    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.fastDuration,
      curve: motion.standardCurve,
      padding: EdgeInsets.only(bottom: _activeRouteViewInsetBottom(context)),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxPanelHeight = math.min(
              math.max(0.0, constraints.maxHeight - 32),
              widget.maxHeight ?? double.infinity,
            );
            final panel = _PanelSurface(
              titleBuilder: widget.titleBuilder,
              scrollController: _scrollController,
              centered: true,
              showHeader: widget.showHeader,
              child: widget.builder(context, _scrollController),
            );
            return Center(
              child: SizedBox(
                width: widget.width.clamp(320, size.width * 0.9).toDouble(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanelHeight),
                  child: panel,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

double _activeRouteViewInsetBottom(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isCurrent) return 0;
  return MediaQuery.viewInsetsOf(context).bottom;
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.titleBuilder,
    required this.scrollController,
    required this.child,
    this.centered = false,
    this.showHeader = true,
  });

  final WidgetBuilder titleBuilder;
  final ScrollController scrollController;
  final Widget child;
  final bool centered;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: Material(
          key: ValueKey(
            centered ? 'adaptive-centered-form' : 'adaptive-bottom-sheet',
          ),
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: centered
                ? BorderRadius.circular(24)
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (!centered)
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
              if (showHeader) ...[
                ColoredBox(
                  key: const ValueKey('adaptive-panel-header-surface'),
                  color: sectionSurfaceColor(theme.colorScheme),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 20,
                        end: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DefaultTextStyle.merge(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              child: titleBuilder(context),
                            ),
                          ),
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
                ),
              ],
              Flexible(
                fit: centered ? FlexFit.loose : FlexFit.tight,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: PrimaryScrollController(
                    controller: scrollController,
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
