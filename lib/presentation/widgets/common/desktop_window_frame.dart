import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/windowing/desktop_window_controller.dart';
import '../../../l10n/app_localizations.dart';

const double desktopWindowHeaderHeight = 40;
const double desktopWindowButtonWidth = 48;

/// Adds the app-managed caption used by the main Windows window.
///
/// Other platforms keep their native title bars. On Windows,
/// `TitleBarStyle.hidden` retains the native resizable frame while this widget
/// supplies the visible caption controls and drag region.
class DesktopWindowFrame extends StatefulWidget {
  const DesktopWindowFrame({
    super.key,
    required this.child,
    this.controller = const WindowManagerDesktopWindowController(),
    this.enabled,
  });

  final Widget child;
  final DesktopWindowController controller;
  final bool? enabled;

  @override
  State<DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends State<DesktopWindowFrame> {
  Size? _lastValidViewport;

  bool _isValidViewport(BoxConstraints constraints) {
    return constraints.hasBoundedWidth &&
        constraints.hasBoundedHeight &&
        constraints.maxWidth.isFinite &&
        constraints.maxHeight.isFinite &&
        constraints.maxHeight >= desktopWindowHeaderHeight &&
        constraints.maxWidth >= desktopWindowButtonWidth * 3;
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.enabled ?? PlatformCapabilities.current.isWindows)) {
      return widget.child;
    }

    final surfaceColor = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentViewport = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final isViewportValid = _isValidViewport(constraints);
        if (isViewportValid) _lastValidViewport = currentViewport;

        // The native view can report a zero or taskbar-sized surface while the
        // top-level window is being minimized. Keep the same element tree laid
        // out at its last real viewport so responsive shells and route state do
        // not churn during that transient native lifecycle state.
        final layoutViewport = isViewportValid
            ? currentViewport
            : _lastValidViewport ??
                  const Size(
                    desktopWindowButtonWidth * 3,
                    desktopWindowHeaderHeight,
                  );

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: layoutViewport.width,
            maxWidth: layoutViewport.width,
            minHeight: layoutViewport.height,
            maxHeight: layoutViewport.height,
            child: SizedBox.fromSize(
              size: layoutViewport,
              child: TickerMode(
                enabled: isViewportValid,
                child: ExcludeSemantics(
                  excluding: !isViewportValid,
                  child: IgnorePointer(
                    ignoring: !isViewportValid,
                    child: ColoredBox(
                      color: surfaceColor,
                      child: Column(
                        children: [
                          DesktopWindowHeader(controller: widget.controller),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DesktopWindowHeader extends StatefulWidget {
  const DesktopWindowHeader({
    super.key,
    this.controller = const WindowManagerDesktopWindowController(),
  });

  final DesktopWindowController controller;

  @override
  State<DesktopWindowHeader> createState() => _DesktopWindowHeaderState();
}

class _DesktopWindowHeaderState extends State<DesktopWindowHeader>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(this);
    unawaited(_syncMaximizedState());
  }

  @override
  void didUpdateWidget(covariant DesktopWindowHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(this);
    widget.controller.addListener(this);
    unawaited(_syncMaximizedState());
  }

  @override
  void dispose() {
    widget.controller.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximizedState() async {
    try {
      final isMaximized = await widget.controller.isMaximized();
      if (mounted && isMaximized != _isMaximized) {
        setState(() => _isMaximized = isMaximized);
      }
    } catch (error) {
      AppLogger.w(
        'Failed to read Windows maximize state: $error',
        'DesktopWindowHeader',
      );
    }
  }

  Future<void> _toggleMaximized() async {
    if (_isMaximized) {
      await widget.controller.unmaximize();
    } else {
      await widget.controller.maximize();
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted && !_isMaximized) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted && _isMaximized) setState(() => _isMaximized = false);
  }

  @override
  void onWindowRestore() => unawaited(_syncMaximizedState());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      key: const ValueKey('desktop-window-header'),
      color: colors.surfaceContainerLow,
      child: DecoratedBox(
        key: const ValueKey('desktop-window-header-divider'),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.10),
            ),
          ),
        ),
        child: SizedBox(
          height: desktopWindowHeaderHeight,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('desktop-window-drag-region'),
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    unawaited(widget.controller.startDragging());
                  },
                  onDoubleTap: _toggleMaximized,
                  child: SizedBox.expand(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Semantics(
                          header: true,
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/Icon.png',
                                  key: const ValueKey(
                                    'desktop-window-project-icon',
                                  ),
                                  width: 24,
                                  height: 24,
                                  filterQuality: FilterQuality.none,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'NAI Launcher',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _CaptionButton(
                key: const ValueKey('desktop-window-minimize'),
                tooltip: l10n.desktopWindow_minimize,
                icon: Icons.remove,
                onPressed: widget.controller.minimize,
              ),
              _CaptionButton(
                key: const ValueKey('desktop-window-maximize'),
                tooltip: _isMaximized
                    ? l10n.desktopWindow_restore
                    : l10n.desktopWindow_maximize,
                icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
                onPressed: _toggleMaximized,
              ),
              _CaptionButton(
                key: const ValueKey('desktop-window-close'),
                tooltip: l10n.desktopWindow_close,
                icon: Icons.close,
                danger: true,
                onPressed: widget.controller.close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: IconButton(
        tooltip: null,
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        color: colors.onSurface,
        hoverColor: danger
            ? colors.error.withValues(alpha: 0.82)
            : colors.onSurface.withValues(alpha: 0.08),
        focusColor: danger
            ? colors.error.withValues(alpha: 0.7)
            : colors.primary.withValues(alpha: 0.18),
        highlightColor: danger
            ? colors.error.withValues(alpha: 0.68)
            : colors.onSurface.withValues(alpha: 0.12),
        style: IconButton.styleFrom(
          minimumSize: const Size(
            desktopWindowButtonWidth,
            desktopWindowHeaderHeight,
          ),
          maximumSize: const Size(
            desktopWindowButtonWidth,
            desktopWindowHeaderHeight,
          ),
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
        ),
      ),
    );
  }
}
