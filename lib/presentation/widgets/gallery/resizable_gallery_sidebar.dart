import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/windowing/workspace_side_panel_contract.dart';
import '../../adaptive/interaction_policy.dart';
import '../common/app_toast.dart';
import '../common/horizontal_resize_handle.dart';
import '../common/resizable_pane.dart';

/// Keeps pointer-rate layout changes out of page state and disk writes.
class ResizableGallerySidebar extends ConsumerStatefulWidget {
  const ResizableGallerySidebar({
    super.key,
    required this.storageKey,
    required this.workspaceWidth,
    required this.initialWidth,
    required this.child,
  });

  final String storageKey;
  final double workspaceWidth;
  final double initialWidth;
  final Widget child;

  @override
  ConsumerState<ResizableGallerySidebar> createState() =>
      _ResizableGallerySidebarState();
}

class _ResizableGallerySidebarState
    extends ConsumerState<ResizableGallerySidebar> {
  late final LocalStorageService _storage;
  late final ResizablePaneController _width;
  final _focusNode = FocusNode();
  bool _focused = false;
  late double _savedWidth;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(localStorageServiceProvider);
    final saved = _storage.getSetting<num>(widget.storageKey);
    _savedWidth = saved != null && saved.isFinite && saved > 0
        ? saved.toDouble()
        : widget.initialWidth;
    _width = ResizablePaneController(initialWidth: _savedWidth);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _width.dispose();
    super.dispose();
  }

  Future<void> _saveWidth() async {
    final width = _width.width;
    if (width == _savedWidth) return;
    try {
      await _storage.setSetting(widget.storageKey, width);
      _savedWidth = width;
    } catch (error, stack) {
      AppLogger.e(
        'Failed to persist sidebar width: ${widget.storageKey}',
        error,
        stack,
        'GallerySidebar',
      );
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.globalSettings_saveFailed(error.toString()),
        );
      }
    }
  }

  void _step(double delta) {
    _width.resizeBy(delta);
    unawaited(_saveWidth());
  }

  @override
  Widget build(BuildContext context) {
    final policy = context.interactionPolicy;
    final handleWidth = policy.prefersTouchPresentation
        ? policy.minimumControlExtent
        : ResizeHandle.defaultWidth;
    final maximum = WorkspaceSidePanelContract.constrainedWorkspaceWidth(
      workspaceWidth: widget.workspaceWidth,
      preferredWidth: WorkspaceSidePanelContract.maximumWidth,
      occupiedWidth: handleWidth,
      minimumPrimaryWidth: 320,
      minimumWidth: 220,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResizablePane(
          key: const ValueKey('gallery-resizable-sidebar'),
          controller: _width,
          minimumWidth: 220.0.clamp(0, maximum).toDouble(),
          maximumWidth: maximum,
          child: widget.child,
        ),
        Focus(
          focusNode: _focusNode,
          onFocusChange: (focused) => setState(() => _focused = focused),
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _step(-16);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _step(16);
            } else if (event.logicalKey == LogicalKeyboardKey.home) {
              _step(widget.initialWidth - _width.width);
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: Semantics(
            label: context.l10n.gallery_resizeSidebar,
            onIncrease: () => _step(16),
            onDecrease: () => _step(-16),
            child: Tooltip(
              message: context.l10n.gallery_resizeSidebar,
              child: ColoredBox(
                color: _focused && policy.keyboardNavigationActive
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                child: ResizeHandle(
                  key: const ValueKey('gallery-sidebar-resize-handle'),
                  width: handleWidth,
                  onDragStart: _focusNode.requestFocus,
                  onDrag: _width.resizeBy,
                  onDragEnd: () => unawaited(_saveWidth()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
