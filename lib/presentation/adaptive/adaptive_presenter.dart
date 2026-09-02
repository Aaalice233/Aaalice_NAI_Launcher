import 'package:flutter/material.dart';

import '../../core/windowing/workspace_side_panel_contract.dart';
import '../themes/theme_extension.dart';
import 'window_size_class.dart';

typedef AdaptivePanelBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Presents secondary controls without forcing one desktop or mobile surface.
class AdaptivePresenter {
  AdaptivePresenter._();

  /// Presents long-form editing flows full-screen on compact panes while
  /// retaining the regular adaptive panel treatment elsewhere.
  static Future<T?> showForm<T>({
    required BuildContext context,
    String? title,
    WidgetBuilder? titleBuilder,
    required AdaptivePanelBuilder builder,
    double? sideSheetWidth,
    bool barrierDismissible = true,
    bool requestFocus = true,
    bool restoreFocus = true,
    bool showHeader = true,
  }) async {
    assert(!showHeader || title != null || titleBuilder != null);
    final metrics = context.adaptiveWindow;
    if (metrics.isExpandedOrWider) {
      return showPanel<T>(
        context: context,
        title: title,
        titleBuilder: titleBuilder,
        builder: builder,
        sideSheetWidth: sideSheetWidth,
        barrierDismissible: barrierDismissible,
        requestFocus: requestFocus,
        restoreFocus: restoreFocus,
        showHeader: showHeader,
      );
    }

    final resolvedTitleBuilder =
        titleBuilder ??
        (context) =>
            Text(title!, style: Theme.of(context).textTheme.titleLarge);
    final previousFocus = restoreFocus
        ? FocusManager.instance.primaryFocus
        : null;
    if (!metrics.isCompact) {
      final result = await _showCenteredForm<T>(
        context: context,
        titleBuilder: resolvedTitleBuilder,
        builder: builder,
        width: sideSheetWidth ?? WorkspaceSidePanelContract.preferredFormWidth,
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Theme.of(context).appTheme;
    final result = await showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierDismissible
          ? MaterialLocalizations.of(context).modalBarrierDismissLabel
          : null,
      requestFocus: requestFocus,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
      transitionDuration: reduceMotion ? Duration.zero : motion.fastDuration,
      pageBuilder: (dialogContext, _, __) => _FullScreenPanel(
        titleBuilder: resolvedTitleBuilder,
        builder: builder,
        showHeader: showHeader,
      ),
      transitionBuilder: (context, animation, _, child) {
        if (reduceMotion) return child;
        return FadeTransition(opacity: animation, child: child);
      },
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

  static Future<T?> showPanel<T>({
    required BuildContext context,
    String? title,
    WidgetBuilder? titleBuilder,
    required AdaptivePanelBuilder builder,
    double initialChildSize = 0.72,
    double minChildSize = 0.38,
    double maxChildSize = 0.94,
    double? sideSheetWidth,
    bool barrierDismissible = true,
    bool allowDragDismissal = true,
    bool requestFocus = true,
    bool restoreFocus = true,
    bool showHeader = true,
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
      presentation = _showSideSheet<T>(
        context: context,
        titleBuilder: resolvedTitleBuilder,
        builder: builder,
        width: WorkspaceSidePanelContract.overlayWidth(
          metrics.safeUsableSize.width,
          preferredWidth: sideSheetWidth,
        ),
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
        builder: (sheetContext) => AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(sheetContext)
              ? Duration.zero
              : motion.fastDuration,
          curve: motion.standardCurve,
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
      ),
      transitionBuilder: (context, animation, _, child) {
        if (reduceMotion) return child;
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  static Future<T?> _showSideSheet<T>({
    required BuildContext context,
    required WidgetBuilder titleBuilder,
    required AdaptivePanelBuilder builder,
    required double width,
    required bool barrierDismissible,
    required bool requestFocus,
    required bool showHeader,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motion = Theme.of(context).appTheme;
    return showGeneralDialog<T>(
      context: context,
      anchorPoint: Offset(MediaQuery.sizeOf(context).width - 1, 0),
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierDismissible
          ? MaterialLocalizations.of(context).modalBarrierDismissLabel
          : null,
      requestFocus: requestFocus,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
      transitionDuration: reduceMotion ? Duration.zero : motion.normalDuration,
      pageBuilder: (dialogContext, _, __) => _SideSheetPanel(
        width: width,
        titleBuilder: titleBuilder,
        builder: builder,
        showHeader: showHeader,
      ),
      transitionBuilder: (context, animation, _, child) {
        if (reduceMotion) return child;
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: motion.enterCurve),
              ),
          child: child,
        );
      },
    );
  }
}

class _FullScreenPanel extends StatefulWidget {
  const _FullScreenPanel({
    required this.titleBuilder,
    required this.builder,
    required this.showHeader,
  });

  final WidgetBuilder titleBuilder;
  final AdaptivePanelBuilder builder;
  final bool showHeader;

  @override
  State<_FullScreenPanel> createState() => _FullScreenPanelState();
}

class _FullScreenPanelState extends State<_FullScreenPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = Theme.of(context).appTheme;
    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.fastDuration,
      curve: motion.standardCurve,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox.expand(
            child: _PanelSurface(
              titleBuilder: widget.titleBuilder,
              scrollController: _scrollController,
              fullScreen: true,
              showHeader: widget.showHeader,
              child: widget.builder(context, _scrollController),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredFormPanel extends StatefulWidget {
  const _CenteredFormPanel({
    required this.width,
    required this.titleBuilder,
    required this.builder,
    required this.showHeader,
  });

  final double width;
  final WidgetBuilder titleBuilder;
  final AdaptivePanelBuilder builder;
  final bool showHeader;

  @override
  State<_CenteredFormPanel> createState() => _CenteredFormPanelState();
}

class _CenteredFormPanelState extends State<_CenteredFormPanel> {
  static const _minimumCenteredHeight = 560.0;

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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useFullScreen =
                constraints.maxHeight < _minimumCenteredHeight;
            return Center(
              child: SizedBox(
                width: useFullScreen
                    ? double.infinity
                    : widget.width.clamp(320, size.width * 0.9).toDouble(),
                height: useFullScreen
                    ? double.infinity
                    : constraints.maxHeight * 0.9,
                child: _PanelSurface(
                  titleBuilder: widget.titleBuilder,
                  scrollController: _scrollController,
                  fullScreen: useFullScreen,
                  centered: !useFullScreen,
                  showHeader: widget.showHeader,
                  child: widget.builder(context, _scrollController),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SideSheetPanel extends StatefulWidget {
  const _SideSheetPanel({
    required this.width,
    required this.titleBuilder,
    required this.builder,
    required this.showHeader,
  });

  final double width;
  final WidgetBuilder titleBuilder;
  final AdaptivePanelBuilder builder;
  final bool showHeader;

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
    final motion = Theme.of(context).appTheme;
    return AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.fastDuration,
      curve: motion.standardCurve,
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
              showHeader: widget.showHeader,
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
    this.fullScreen = false,
    this.centered = false,
    this.showHeader = true,
  });

  final WidgetBuilder titleBuilder;
  final ScrollController scrollController;
  final Widget child;
  final bool sideSheet;
  final bool fullScreen;
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
            fullScreen
                ? 'adaptive-full-screen-form'
                : centered
                ? 'adaptive-centered-form'
                : sideSheet
                ? 'adaptive-side-sheet'
                : 'adaptive-bottom-sheet',
          ),
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: fullScreen
                ? BorderRadius.zero
                : centered
                ? BorderRadius.circular(24)
                : sideSheet
                ? const BorderRadius.horizontal(left: Radius.circular(24))
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              if (!sideSheet && !fullScreen)
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
                ConstrainedBox(
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
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ],
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
        ),
      ),
    );
  }
}
